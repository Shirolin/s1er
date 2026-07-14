import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../config/constants.dart';
import '../config/env_config.dart';
import '../config/resource_domains.dart';
import 'formhash_service.dart';
import 'encrypted_cookie_storage.dart';
import 'talker.dart';

class S1HttpClient {
  S1HttpClient(this._ref) : _testContainer = null;

  @visibleForTesting
  S1HttpClient.test(this._testContainer, Dio dio)
      : _ref = null,
        _dio = dio,
        _initialized = true;

  late Dio _dio;
  bool _initialized = false;
  PersistCookieJar? _cookieJar;
  final List<DateTime> _requestTimestamps = [];
  final Ref? _ref;
  final ProviderContainer? _testContainer;

  static String get _proxyUrl => 'http://localhost:${EnvConfig.proxyPort}';
  static bool get _isWeb => kIsWeb;

  PersistCookieJar get cookieJar => _cookieJar!;
  Dio get dio => _dio;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (!_isWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final cookiePath = '${appDocDir.path}/.cookies/';
      final storage = await EncryptedCookieStorage.create(cookiePath);
      _cookieJar = PersistCookieJar(storage: storage);
    }

    final headers = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
    if (!_isWeb) {
      headers['User-Agent'] = S1Constants.mobileUserAgent;
    }

    _dio = Dio(
      BaseOptions(
        connectTimeout:
            const Duration(seconds: EnvConfig.connectTimeoutSeconds),
        receiveTimeout:
            const Duration(seconds: EnvConfig.receiveTimeoutSeconds),
        sendTimeout: const Duration(seconds: EnvConfig.sendTimeoutSeconds),
        headers: headers,
      ),
    );

    if (_isWeb) {
      _dio.options.extra['withCredentials'] = true;
    }

    if (!_isWeb) {
      _dio.interceptors.add(CookieManager(_cookieJar!));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _enforceRateLimit();

          final currentFormhash = _read(formhashProvider);
          if (currentFormhash.isNotEmpty &&
              (options.method == 'POST' || options.method == 'PUT')) {
            if (!options.path.contains('formhash=')) {
              final separator = options.path.contains('?') ? '&' : '?';
              options.path =
                  '${options.path}${separator}formhash=$currentFormhash';
            }

            if (options.data is Map) {
              final dataMap = options.data as Map;
              if (!dataMap.containsKey('formhash')) {
                dataMap['formhash'] = currentFormhash;
              }
            } else if (options.data is String) {
              final dataStr = options.data as String;
              if (!dataStr.contains('formhash=')) {
                options.data = dataStr.isEmpty
                    ? 'formhash=$currentFormhash'
                    : '$dataStr&formhash=$currentFormhash';
              }
            } else {
              options.data ??= {'formhash': currentFormhash};
            }
          }

          _applyForumPostHeaders(options);

          if (_isWeb) {
            final uri = Uri.parse(options.path);
            final rule = ResourceDomains.match(uri.host);

            if (!options.path.startsWith(_proxyUrl) &&
                rule != null &&
                ResourceDomains.requiresProxy(uri.host)) {
              if (rule.type == ResourceType.authImage) {
                options.path =
                    '$_proxyUrl/img-proxy?url=${Uri.encodeComponent(options.path)}';
              } else if (rule.type == ResourceType.api) {
                final path = uri.path;
                final queryParts = options.path.split('?');
                final rawQuery = queryParts.length > 1
                    ? queryParts.sublist(1).join('?')
                    : '';
                options.path =
                    '$_proxyUrl$path${rawQuery.isNotEmpty ? '?$rawQuery' : ''}';
              }
            } else if (!options.path.startsWith(_proxyUrl) &&
                options.method == 'GET' &&
                options.responseType == ResponseType.bytes &&
                ResourceDomains.isAllowedImgProxyTarget(uri)) {
              options.path =
                  '$_proxyUrl/img-proxy?url=${Uri.encodeComponent(options.path)}';
            }

            // 代理请求注入访问令牌
            if (options.path.startsWith(_proxyUrl) &&
                EnvConfig.proxyAuthToken.isNotEmpty) {
              options.headers[proxyAuthHeader] = EnvConfig.proxyAuthToken;
            }
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          final formhash = FormhashExtractor.fromApiResponse(response.data);
          if (formhash != null) {
            _read(formhashProvider.notifier).update(formhash);
          }
          handler.next(response);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
    _initialized = true;
  }

  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 1),
    );
    if (_requestTimestamps.length >= S1Constants.maxRequestsPerSecond) {
      final oldest = _requestTimestamps.first;
      final waitTime = const Duration(seconds: 1) - now.difference(oldest);
      if (!waitTime.isNegative) {
        await Future.delayed(waitTime);
      }
    }
    _requestTimestamps.add(DateTime.now());
  }

  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(url, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String url, {dynamic data, Options? options}) {
    return _dio.post(url, data: data, options: options);
  }

  void updateFormhash(String formhash) {
    if (formhash.isEmpty) return;
    _read(formhashProvider.notifier).update(formhash);
  }

  /// 发帖前确保 formhash 已从 Mobile API 或回复页 HTML 中缓存。
  ///
  /// [force] 为 true 时丢弃缓存并重新拉取（回复 POST 前必须使用，避免登录等
  /// 操作消耗掉旧的 formhash）。
  Future<bool> ensureFormhash({
    String? tid,
    String? fid,
    bool force = false,
  }) async {
    if (force) {
      _read(formhashProvider.notifier).clear();
    } else if (_read(formhashProvider).isNotEmpty) {
      return true;
    }

    if (tid != null && tid.isNotEmpty) {
      await _fetchFormhashFromMobileApi(
        '${ApiConfig.mobileApiUrl}'
        '?module=${ApiConfig.moduleViewThread}&version=4&tid=$tid',
      );
    }
    if (_read(formhashProvider).isNotEmpty) return true;

    await _fetchFormhashFromMobileApi(
      '${ApiConfig.mobileApiUrl}'
      '?module=${ApiConfig.moduleForumIndex}&version=4',
    );
    if (_read(formhashProvider).isNotEmpty) return true;

    await _fetchFormhashFromMobileApi(
      '${ApiConfig.mobileApiUrl}?module=${ApiConfig.moduleLogin}&version=4',
    );
    if (_read(formhashProvider).isNotEmpty) return true;

    if (fid != null && fid.isNotEmpty && tid != null && tid.isNotEmpty) {
      await _fetchFormhashFromReplyPage(fid: fid, tid: tid);
    }
    return _read(formhashProvider).isNotEmpty;
  }

  /// 登录/登出后刷新 formhash，避免沿用已消耗的验证串。
  Future<void> refreshFormhashAfterAuth() async {
    _read(formhashProvider.notifier).clear();
    await _fetchFormhashFromMobileApi(
      '${ApiConfig.mobileApiUrl}?module=${ApiConfig.moduleLogin}&version=4',
    );
    if (_read(formhashProvider).isNotEmpty) return;

    await _fetchFormhashFromMobileApi(
      '${ApiConfig.mobileApiUrl}'
      '?module=${ApiConfig.moduleForumIndex}&version=4',
    );
  }

  Future<void> _fetchFormhashFromMobileApi(String url) async {
    try {
      final response = await get(url);
      _cacheFormhash(response.data);
    } catch (e, st) {
      talker.handle(e, st, 'Fetch formhash from mobile API failed');
    }
  }

  Future<void> _fetchFormhashFromReplyPage({
    required String fid,
    required String tid,
  }) async {
    try {
      final url = ApiConfig.forumReplyReferer(fid: fid, tid: tid);
      final response = await get(url);
      final html = response.data?.toString() ?? '';
      final formhash = FormhashExtractor.fromHtml(html);
      if (formhash != null) {
        _read(formhashProvider.notifier).update(formhash);
      }
    } catch (e, st) {
      talker.handle(e, st, 'Fetch formhash from reply page failed');
    }
  }

  void _cacheFormhash(dynamic data) {
    final formhash = FormhashExtractor.fromApiResponse(data);
    if (formhash != null) {
      _read(formhashProvider.notifier).update(formhash);
    }
  }

  T _read<T>(ProviderListenable<T> provider) {
    final ref = _ref;
    if (ref != null) return ref.read(provider);
    return _testContainer!.read(provider);
  }

  static void _applyForumPostHeaders(RequestOptions options) {
    if (options.method != 'POST') return;

    final uri = _requestUri(options);
    if (!uri.path.contains('forum.php')) return;
    if (uri.queryParameters['mod'] != 'post') return;

    final action = uri.queryParameters['action'];
    if (!_isWeb) {
      if (action == 'reply') {
        final fid = uri.queryParameters['fid'] ?? '';
        final tid = uri.queryParameters['tid'] ?? '';
        final reppost = uri.queryParameters['reppost'] ?? '0';
        if (fid.isNotEmpty && tid.isNotEmpty) {
          options.headers['Referer'] = ApiConfig.forumReplyReferer(
            fid: fid,
            tid: tid,
            reppost: reppost,
          );
        }
      } else {
        options.headers['Referer'] = ResourceDomains.defaultReferer;
      }
    }
    options.headers['X-Requested-With'] = 'XMLHttpRequest';
  }

  static Uri _requestUri(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    return Uri.parse('https://${ResourceDomains.apiHost}$path');
  }
}

final httpClientProvider = Provider<S1HttpClient>((ref) {
  return S1HttpClient(ref);
});
