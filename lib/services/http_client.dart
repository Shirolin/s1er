import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../utils/cookie_store.dart';

class S1HttpClient {
  static S1HttpClient? _instance;
  late Dio _dio;
  late CookieStore _cookieStore;
  final List<DateTime> _requestTimestamps = [];

  // Web 模式下使用本地 CORS 代理
  static const String _proxyUrl = 'http://localhost:19080';
  static bool get _isWeb => kIsWeb;

  S1HttpClient._() {
    _cookieStore = CookieStore();

    // 浏览器禁止设置 User-Agent 等安全头，Web 模式下不设置
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
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _enforceRateLimit();

        final cookieHeader = _cookieStore.toHeaderString();
        if (cookieHeader.isNotEmpty) {
          options.headers['Cookie'] = cookieHeader;
        }

        // Web 模式下将请求重写到本地代理（代理负责设置安全头）
        if (_isWeb && options.path.contains('stage1st.com')) {
          final uri = Uri.parse(options.path);
          final path = uri.path;
          final query = uri.query;
          options.path = '$_proxyUrl$path${query.isNotEmpty ? '?$query' : ''}';
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
