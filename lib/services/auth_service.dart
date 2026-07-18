import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../models/user.dart';
import 'http_client.dart';
import 'api_service.dart';
import 'talker.dart';
import '../utils/error_handler.dart';

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

  Future<String?> login(
    String username,
    String password, {
    int questionId = 0,
    String answer = '',
  }) async {
    try {
      final apiService = ApiService(_httpClient);
      final error = await apiService.login(
        username,
        password,
        questionId: questionId,
        answer: answer,
      );

      if (error == null) {
        _isLoggedIn = true;
        _currentUser = User(uid: '', username: username);
        await _fetchProfile();
        return null;
      }
      return error;
    } catch (e, st) {
      return friendlyError(e, '登录', st);
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
    if (kIsWeb) {
      try {
        const proxyUrl =
            'http://localhost:${EnvConfig.proxyPort}/proxy/session/clear';
        final headers = <String, dynamic>{};
        if (EnvConfig.proxyAuthToken.isNotEmpty) {
          headers[proxyAuthHeader] = EnvConfig.proxyAuthToken;
        }
        await _httpClient.post(
          proxyUrl,
          options: Options(headers: headers),
        );
      } catch (e, st) {
        talker.handle(e, st, 'Clear proxy session failed');
      }
    }
    _currentUser = null;
    _isLoggedIn = false;
    if (!kIsWeb) {
      await _httpClient.cookieJar.deleteAll();
    }
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
