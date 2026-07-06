import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

final httpClientProvider = Provider<S1HttpClient>((ref) {
  return S1HttpClient.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(httpClient: ref.watch(httpClientProvider));
});

class AuthState {
  final bool isLoggedIn;
  final String? username;

  AuthState({this.isLoggedIn = false, this.username});

  AuthState copyWith({bool? isLoggedIn, String? username}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    state = state.copyWith(
      isLoggedIn: _authService.isLoggedIn,
      username: _authService.currentUser?.username,
    );
  }

  Future<bool> login(String username, String password) async {
    return await _authService.login(username, password);
  }

  void logout() {
    _authService.logout();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
