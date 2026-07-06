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

  /// 新增：由 WebView 成功截获并设置 Cookie 后，直接更新登录状态并拉取当前用户信息
  void setLoggedIn(String username) {
    _isLoggedIn = true;
    _currentUser = User(uid: '', username: username);
    notifyListeners();
  }

  /// 返回 null 表示成功，否则返回错误信息
  Future<String?> login(String username, String password) async {
    if (_httpClient == null) return 'HTTP 客户端未初始化';
    try {
      final apiService = ApiService(_httpClient!);
      final error = await apiService.login(username, password);

      if (error == null) {
        _isLoggedIn = true;
        _currentUser = User(uid: '', username: username);
        notifyListeners();
        return null;
      }
      return error;
    } catch (e) {
      debugPrint('Login failed: $e');
      return '网络错误: $e';
    }
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _httpClient?.cookieJar.deleteAll();
    notifyListeners();
  }

  /// 适配：利用新 CookieJar 检测是否有登录态 Cookie
  Future<void> checkSession() async {
    if (_httpClient == null) return;
    
    // 从 S1 论坛域名读取 Cookie 以校验是否含有登录态
    final cookies = await _httpClient!.cookieJar.loadForRequest(Uri.parse('https://stage1st.com'));
    final hasAuth = cookies.any((c) => c.name.endsWith('auth') && c.value.isNotEmpty);
    if (hasAuth) {
      // 提取 Cookie 中的用户名信息，或临时赋予通用占位
      final memberName = cookies
          .firstWhere((c) => c.name.endsWith('username'),
              orElse: () => Cookie('username', 'S1User'))
          .value;
      _currentUser = User(uid: '', username: Uri.decodeComponent(memberName));
      _isLoggedIn = true;
      notifyListeners();
    }
  }
}
