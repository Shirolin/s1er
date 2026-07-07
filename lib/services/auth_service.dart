import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import '../models/user.dart';
import 'http_client.dart';
import 'api_service.dart';

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
    } catch (e) {
      debugPrint('Login failed: $e');
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
    } catch (e) {
      debugPrint('Fetch profile failed: $e');
    }
    return null;
  }

  Future<User?> fetchProfile() async {
    return await _fetchProfile();
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _httpClient.cookieJar.deleteAll();
  }

  Future<bool> checkSession() async {
    final apiService = ApiService(_httpClient);
    try {
      final profile = await apiService.getUserProfile();
      if (profile != null && profile.uid.isNotEmpty && profile.uid != '0') {
        _currentUser = profile;
        _isLoggedIn = true;
        return true;
      }
    } catch (_) {}

    if (kIsWeb) return false;
    try {
      final cookies = await _httpClient.cookieJar
          .loadForRequest(Uri.parse('https://stage1st.com'));
      final hasAuth =
          cookies.any((c) => c.name.endsWith('auth') && c.value.isNotEmpty);
      if (hasAuth) {
        final memberName = cookies
            .firstWhere((c) => c.name.endsWith('username'),
                orElse: () => Cookie('username', 'S1User'),)
            .value;
        _currentUser =
            User(uid: '', username: Uri.decodeComponent(memberName));
        _isLoggedIn = true;
        unawaited(_fetchProfile());
        return true;
      }
    } catch (_) {}
    return false;
  }
}
