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

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(_init());
    return AuthState();
  }

  AuthService get _authService => ref.read(authServiceProvider);

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
    // readingHistoryServiceProvider 依赖 authStateProvider，须延后读取以免循环依赖。
    Future.delayed(Duration.zero, () {
      if (!ref.mounted) return;
      ref.read(readingHistoryServiceProvider).migrateGuestRecords(uid);
      ref.read(readingHistoryProvider.notifier).refresh();
    });
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
      ref.invalidate(forumListProvider);
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
    await _authService.logout();
    state = AuthState();
    ref.invalidate(forumListProvider);
  }

  /// Test helper: seed auth state without calling the network.
  void debugSetState(AuthState next) => state = next;
}

final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
