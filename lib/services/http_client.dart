import 'dart:async';
import 'dart:convert';
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
import '../providers/unread_count_provider.dart';

class S1HttpClient {
  S1HttpClient(this._ref)
      : _testContainer = null,
        _now = DateTime.now,
        _delay = _defaultDelay;

  @visibleForTesting
  S1HttpClient.test(
    this._testContainer,
    Dio dio, {
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  })  : _ref = null,
        _dio = dio,
        _initialized = true,
        _now = now ?? DateTime.now,
        _delay = delay ?? _defaultDelay;

  late Dio _dio;
  bool _initialized = false;
  PersistCookieJar? _cookieJar;
  final List<DateTime> _apiRequestTimestamps = [];
  final List<DateTime> _mediaRequestTimestamps = [];
  final Ref? _ref;
  final ProviderContainer? _testContainer;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  Future<void> _apiRateLimitQueue = Future.value();
  Future<void> _mediaRateLimitQueue = Future.value();

  static String get _proxyUrl => 'http://localhost:${EnvConfig.proxyPort}';
  static bool get _isWeb => kIsWeb;

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

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
        connectTimeout: const Duration(
          seconds: EnvConfig.connectTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: EnvConfig.receiveTimeoutSeconds,
        ),
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
          await _enforceRateLimit(isMedia: _isMediaRequest(options));

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
          _extractAndUpdateNotice(response.data);
          handler.next(response);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
    _initialized = true;
  }

  static bool _isMediaRequest(RequestOptions options) {
    if (options.responseType == ResponseType.bytes) return true;
    final flag = options.extra['s1Media'];
    return flag == true;
  }

  Future<void> _enforceRateLimit({bool isMedia = false}) async {
    final previous = isMedia ? _mediaRateLimitQueue : _apiRateLimitQueue;
    final gate = Completer<void>();
    if (isMedia) {
      _mediaRateLimitQueue = gate.future;
    } else {
      _apiRateLimitQueue = gate.future;
    }
    await previous;

    final timestamps =
        isMedia ? _mediaRequestTimestamps : _apiRequestTimestamps;
    final maxPerSecond = isMedia
        ? S1Constants.maxMediaRequestsPerSecond
        : S1Constants.maxRequestsPerSecond;

    try {
      while (true) {
        final now = _now();
        timestamps.removeWhere(
          (timestamp) =>
              now.difference(timestamp) >= const Duration(seconds: 1),
        );
        if (timestamps.length < maxPerSecond) {
          timestamps.add(_now());
          return;
        }

        final oldest = timestamps.first;
        final waitTime = const Duration(seconds: 1) - now.difference(oldest);
        if (waitTime.isNegative || waitTime == Duration.zero) {
          continue;
        }
        await _delay(waitTime);
      }
    } finally {
      gate.complete();
    }
  }

  @visibleForTesting
  Future<void> debugEnforceRateLimit({bool isMedia = false}) =>
      _enforceRateLimit(isMedia: isMedia);

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

  /// 当前缓存的 formhash；空字符串表示尚未取得。
  String get currentFormhash => _read(formhashProvider);

  /// 缓存任意 Mobile API 响应中的 formhash。
  ///
  /// 新主题预检本身就是权限与表单来源，不能再退回到可能不匹配的
  /// forumindex/viewthread 响应。
  void cacheFormhashFromResponse(dynamic data) {
    _cacheFormhash(data);
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

  /// 确保 formhash 可用并返回 token；失败时返回 `null`。
  ///
  /// 供需要显式把 formhash 放入 GET query 的场景（每日签到），不改变
  /// 现有 POST/PUT 自动注入行为。
  Future<String?> requireFormhash({bool force = false}) async {
    final ok = await ensureFormhash(force: force);
    if (!ok) return null;
    final token = currentFormhash;
    return token.isEmpty ? null : token;
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

  void _extractAndUpdateNotice(dynamic data) {
    try {
      Map<String, dynamic>? jsonMap;
      if (data is Map) {
        jsonMap = Map<String, dynamic>.from(data);
      } else if (data is String) {
        final trimmed = data.trimLeft();
        if (trimmed.startsWith('{')) {
          jsonMap = jsonDecode(data) as Map<String, dynamic>?;
        }
      }

      if (jsonMap != null) {
        final variables = jsonMap['Variables'];
        if (variables is Map && variables.containsKey('notice')) {
          final noticeMap = variables['notice'];
          if (noticeMap is Map) {
            _read(unreadCountProvider.notifier)
                .updateFromNotice(Map<String, dynamic>.from(noticeMap));
          }
        }
      }
    } catch (_) {}
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
