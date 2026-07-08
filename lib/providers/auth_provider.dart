import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/talker_provider.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    httpClient: ref.watch(httpClientProvider),
    talker: ref.watch(talkerProvider),
  );
});

class AuthState {

  AuthState({this.isLoggedIn = false, this.username, this.user});
  final bool isLoggedIn;
  final String? username;
  final User? user;

  AuthState copyWith({bool? isLoggedIn, String? username, User? user}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {

  AuthNotifier(this._authService) : super(AuthState()) {
    _init();
  }
  final AuthService _authService;

  Future<void> _init() async {
    final ok = await _authService.checkSession();
    if (ok) {
      state = AuthState(
        isLoggedIn: true,
        username: _authService.currentUser?.username,
        user: _authService.currentUser,
      );
    }
  }

  void setLoggedIn(String username) {
    _authService.setLoggedIn(username);
    state = AuthState(
      isLoggedIn: true,
      username: username,
      user: _authService.currentUser,
    );
    unawaited(_authService.fetchProfile().then((user) {
      if (user != null) {
        try {
          state = state.copyWith(user: user, username: user.username);
        } catch (_) {}
      }
    }),);
  }

  Future<String?> login(String username, String password) async {
    final error = await _authService.login(username, password);
    if (error == null) {
      state = AuthState(
        isLoggedIn: true,
        username: _authService.currentUser?.username,
        user: _authService.currentUser,
      );
      unawaited(_authService.fetchProfile().then((user) {
        if (user != null) {
          try {
            state = state.copyWith(user: user, username: user.username);
          } catch (_) {}
        }
      }),);
    }
    return error;
  }

  Future<void> refreshProfile() async {
    final user = await _authService.fetchProfile();
    if (user != null) {
      try {
        state = state.copyWith(user: user, username: user.username);
      } catch (_) {}
    }
  }

  void logout() {
    _authService.logout();
    state = AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
