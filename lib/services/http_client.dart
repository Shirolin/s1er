import 'dart:async';
import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../utils/cookie_store.dart';

class S1HttpClient {
  static S1HttpClient? _instance;
  late Dio _dio;
  late CookieStore _cookieStore;
  final List<DateTime> _requestTimestamps = [];

  S1HttpClient._() {
    _cookieStore = CookieStore();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': S1Constants.mobileUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _enforceRateLimit();

        final cookieHeader = _cookieStore.toHeaderString();
        if (cookieHeader.isNotEmpty) {
          options.headers['Cookie'] = cookieHeader;
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        _extractCookies(response);
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  static S1HttpClient get instance {
    _instance ??= S1HttpClient._();
    return _instance!;
  }

  /// Reset the singleton — useful in tests.
  static void resetInstance() {
    _instance = null;
  }

  CookieStore get cookieStore => _cookieStore;

  Future<void> init() async {
    await _cookieStore.init();
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

  void _extractCookies(Response response) {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      final cookies = <String, String>{};
      for (final header in setCookieHeaders) {
        final parts = header.split(';')[0].split('=');
        if (parts.length >= 2) {
          cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
      if (cookies.isNotEmpty) {
        _cookieStore.setCookies(cookies);
      }
    }
  }

  Future<Response> get(String url, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(url, queryParameters: queryParameters);
  }

  Future<Response> post(String url, {Map<String, dynamic>? data}) {
    return _dio.post(url, data: data);
  }
}
