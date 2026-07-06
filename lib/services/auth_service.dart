import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
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

  void setLoggedIn(String username) {
    _isLoggedIn = true;
    _currentUser = User(uid: '', username: username);
    notifyListeners();
    _fetchProfile();
  }

  Future<String?> login(String username, String password) async {
    final httpClient = _httpClient;
    if (httpClient == null) return 'HTTP 客户端未初始化';
    try {
      final apiService = ApiService(httpClient);
      final error = await apiService.login(username, password);

      if (error == null) {
        _isLoggedIn = true;
        _currentUser = User(uid: '', username: username);
        notifyListeners();
        _fetchProfile();
        return null;
      }
      return error;
    } catch (e) {
      debugPrint('Login failed: $e');
      return '网络错误: $e';
    }
  }

  Future<void> _fetchProfile() async {
    final httpClient = _httpClient;
    if (httpClient == null) return;
    try {
      final apiService = ApiService(httpClient);
      final profile = await apiService.getUserProfile();
      if (profile != null) {
        _currentUser = profile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch profile failed: $e');
    }
  }

  Future<void> refreshProfile() async {
    await _fetchProfile();
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _httpClient?.cookieJar.deleteAll();
    notifyListeners();
  }

  Future<void> checkSession() async {
    final httpClient = _httpClient;
    if (httpClient == null) return;

    // Web 模式下 cookieJar 是内存存储，重启后为空，但浏览器会自动带 Cookie
    // 所以直接尝试拉取用户资料来判断是否已登录
    final apiService = ApiService(httpClient);
    try {
      final profile = await apiService.getUserProfile();
      if (profile != null && profile.uid.isNotEmpty && profile.uid != '0') {
        _currentUser = profile;
        _isLoggedIn = true;
        notifyListeners();
        return;
      }
    } catch (_) {}

    // 降级：从 cookieJar 检查（非 Web 平台）
    if (kIsWeb) return;
    try {
      final cookies = await httpClient.cookieJar
          .loadForRequest(Uri.parse('https://stage1st.com'));
      final hasAuth =
          cookies.any((c) => c.name.endsWith('auth') && c.value.isNotEmpty);
      if (hasAuth) {
        final memberName = cookies
            .firstWhere((c) => c.name.endsWith('username'),
                orElse: () => Cookie('username', 'S1User'))
            .value;
        _currentUser =
            User(uid: '', username: Uri.decodeComponent(memberName));
        _isLoggedIn = true;
        notifyListeners();
        _fetchProfile();
      }
    } catch (_) {}
  }
}
