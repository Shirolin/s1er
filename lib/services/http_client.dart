import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';
import 'formhash_service.dart';

class S1HttpClient {

  S1HttpClient(this._ref);
  late Dio _dio;
  late PersistCookieJar _cookieJar;
  final List<DateTime> _requestTimestamps = [];
  final Ref _ref;

  static const String _proxyUrl = 'http://localhost:19080';
  static bool get _isWeb => kIsWeb;

  PersistCookieJar get cookieJar => _cookieJar;

  Future<void> init() async {
    if (_isWeb) {
      _cookieJar = PersistCookieJar();
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      final cookiePath = '${appDocDir.path}/.cookies/';
      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookiePath),
      );
    }

    final headers = <String, String>{
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
    if (!_isWeb) {
      headers['User-Agent'] = S1Constants.mobileUserAgent;
    }

    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: headers,
    ),);

    if (_isWeb) {
      _dio.options.extra['withCredentials'] = true;
    }

    if (!_isWeb) {
      _dio.interceptors.add(CookieManager(_cookieJar));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _enforceRateLimit();

        final currentFormhash = _ref.read(formhashProvider);
        if (currentFormhash.isNotEmpty &&
            (options.method == 'POST' || options.method == 'PUT')) {
          if (!options.path.contains('formhash=')) {
            final separator = options.path.contains('?') ? '&' : '?';
            options.path = '${options.path}${separator}formhash=$currentFormhash';
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

        if (_isWeb && options.path.contains('stage1st.com')) {
          final uri = Uri.parse(options.path);
          final path = uri.path;
          final queryParts = options.path.split('?');
          final rawQuery = queryParts.length > 1 ? queryParts.sublist(1).join('?') : '';
          options.path = '$_proxyUrl$path${rawQuery.isNotEmpty ? '?$rawQuery' : ''}';
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final variables = data['Variables'];
          if (variables is Map<String, dynamic>) {
            final formhash = variables['formhash'];
            if (formhash is String) {
              _ref.read(formhashProvider.notifier).update(formhash);
            }
          }
        }
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ),);
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

  Future<Response> get(String url, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(url, queryParameters: queryParameters);
  }

  Future<Response> post(String url, {dynamic data, Options? options}) {
    return _dio.post(url, data: data, options: options);
  }
}

final httpClientProvider = Provider<S1HttpClient>((ref) {
  return S1HttpClient(ref);
});
