import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';
import 'forum_list_provider.dart';
import 'reading_history_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(httpClient: ref.watch(httpClientProvider));
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

  AuthNotifier(this._authService, this._ref) : super(AuthState()) {
    _init();
  }
  final AuthService _authService;
  final Ref _ref;

  Future<void> _init() async {
    final ok = await _authService.checkSession();
    if (ok) {
      _syncStateFromService();
    }
  }

  void _syncStateFromService() {
    state = AuthState(
      isLoggedIn: true,
      username: _authService.currentUser?.username,
      user: _authService.currentUser,
    );
    _maybeMigrateGuestHistory();
  }

  void _maybeMigrateGuestHistory() {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    _ref.read(readingHistoryServiceProvider).migrateGuestRecords(uid);
    _ref.read(readingHistoryProvider.notifier).refresh();
  }

  void setLoggedIn(String username) {
    _authService.setLoggedIn(username);
    _syncStateFromService();
  }

  Future<String?> login(String username, String password) async {
    final error = await _authService.login(username, password);
    if (error == null) {
      _syncStateFromService();
      await _waitForProfile();
      _ref.invalidate(forumListProvider);
    }
    return error;
  }

  Future<void> _waitForProfile() async {
    for (var i = 0; i < 20; i++) {
      final user = _authService.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        state = state.copyWith(user: user, username: user.username);
        _maybeMigrateGuestHistory();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> refreshProfile() async {
    final user = await _authService.fetchProfile();
    if (user != null) {
      try {
        state = state.copyWith(user: user, username: user.username);
        _maybeMigrateGuestHistory();
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      state = AuthState();
      _ref.invalidate(forumListProvider);
    } catch (e) {
      rethrow;
    }
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});
