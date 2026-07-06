import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'http_client.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final S1HttpClient? _httpClient;
  User? _currentUser;
  bool _isLoggedIn = false;

  AuthService({S1HttpClient? httpClient}) : _httpClient = httpClient;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String username, String password) async {
    if (_httpClient == null) return false;
    try {
      final apiService = ApiService(_httpClient!);
      final success = await apiService.login(username, password);

      if (success) {
        _isLoggedIn = true;
        _currentUser = User(uid: '', username: username);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login failed: $e');
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _httpClient?.cookieStore.clear();
    notifyListeners();
  }

  void restoreSession(Map<String, String> cookies) {
    if (cookies.isNotEmpty) {
      _httpClient?.cookieStore.setCookies(cookies);
      _isLoggedIn = true;
      notifyListeners();
    }
  }
}
