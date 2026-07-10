import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../models/user.dart';
import 'http_client.dart';
import 'api_service.dart';
import 'talker.dart';

class AuthService {

  AuthService({required S1HttpClient httpClient}) : _httpClient = httpClient;
  final S1HttpClient _httpClient;

  User? _currentUser;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  void setLoggedIn(String username) {
    _isLoggedIn = true;
    _currentUser = User(uid: '', username: username);
    unawaited(_fetchProfile());
  }

  Future<String?> login(String username, String password) async {
    if (!kIsWeb) {
      throw UnsupportedError('Native login must use WebView');
    }
    try {
      final apiService = ApiService(_httpClient);
      final error = await apiService.login(username, password);

      if (error == null) {
        _isLoggedIn = true;
        _currentUser = User(uid: '', username: username);
        unawaited(_fetchProfile());
        return null;
      }
      return error;
    } catch (e, st) {
      talker.handle(e, st, 'Login failed');
      return '网络错误: $e';
    }
  }

  Future<User?> _fetchProfile() async {
    try {
      final apiService = ApiService(_httpClient);
      final profile = await apiService.getUserProfile();
      if (profile != null) {
        _currentUser = profile;
        return profile;
      }
    } catch (e, st) {
      talker.handle(e, st, 'Fetch profile failed');
    }
    return null;
  }

  Future<User?> fetchProfile() async {
    return await _fetchProfile();
  }

  Future<void> logout() async {
    if (kIsWeb && EnvConfig.proxyAuthToken.isNotEmpty) {
      try {
        final proxyUrl =
            'http://localhost:${EnvConfig.proxyPort}/proxy/session/clear';
        await _httpClient.post(
          proxyUrl,
          options: Options(
            headers: {proxyAuthHeader: EnvConfig.proxyAuthToken},
          ),
        );
      } catch (e, st) {
        talker.handle(e, st, 'Clear proxy session failed');
      }
    }
    _currentUser = null;
    _isLoggedIn = false;
    await _httpClient.cookieJar.deleteAll();
  }

  /// WebView 登录成功后同步 Cookie 并拉取资料
  Future<String?> completeWebViewLogin() async {
    try {
      final ok = await checkSession();
      if (!ok) {
        return '登录未完成，请重试';
      }
      final profile = await _fetchProfile();
      if (profile == null || profile.uid.isEmpty) {
        return '获取用户资料失败';
      }
      return null;
    } catch (e, st) {
      talker.handle(e, st, 'WebView login completion failed');
      return '登录失败: $e';
    }
  }

  /// 将 WebView 读取的 Cookie 写入本地 CookieJar（原生平台）
  Future<void> importWebViewCookies(List<Cookie> cookies) async {
    if (kIsWeb) return;
    final uri = Uri.parse('https://stage1st.com/2b/');
    await _httpClient.cookieJar.saveFromResponse(uri, cookies);
  }

  Future<bool> checkSession() async {
    final apiService = ApiService(_httpClient);

    // 1. 优先通过 API 验证会话（Cookie 由 CookieManager 自动附加）
    try {
      final profile = await apiService.getUserProfile();
      if (profile != null && profile.uid.isNotEmpty && profile.uid != '0') {
        _currentUser = profile;
        _isLoggedIn = true;
        return true;
      }
    } catch (_) {}

    // 2. API 验证失败时，检查本地 PersistCookieJar 中是否有 auth Cookie
    //    尝试多个路径以覆盖 Discuz 不同的 Cookie Path 设置
    if (kIsWeb) return false;
    try {
      final urls = [
        Uri.parse('https://stage1st.com/2b/'),
        Uri.parse('https://stage1st.com'),
      ];
      for (final uri in urls) {
        final cookies = await _httpClient.cookieJar.loadForRequest(uri);
        final hasAuth =
            cookies.any((c) => c.name.endsWith('auth') && c.value.isNotEmpty);
        if (hasAuth) {
          final memberName = cookies
              .firstWhere(
                (c) => c.name.endsWith('username'),
                orElse: () => Cookie('username', 'S1User'),
              )
              .value;
          _currentUser =
              User(uid: '', username: Uri.decodeComponent(memberName));
          _isLoggedIn = true;
          unawaited(_fetchProfile());
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
