import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';
import 'forum_list_provider.dart';
import 'settings_provider.dart';

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

  @override
  bool operator ==(Object other) {
    return other is AuthState &&
        other.isLoggedIn == isLoggedIn &&
        other.username == username &&
        other.user == user;
  }

  @override
  int get hashCode => Object.hash(isLoggedIn, username, user);
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
    if (!ref.mounted) return;
    if (ok) {
      await _applyLoginSuccess();
    }
  }

  Future<void> _applyLoginSuccess() async {
    if (!ref.mounted) return;
    _syncStateFromService();
    if (state.user == null || state.user!.uid.isEmpty) {
      await refreshProfile();
    }
    if (ref.mounted) ref.invalidate(forumListProvider);
  }

  void _syncStateFromService() {
    final next = AuthState(
      isLoggedIn: true,
      username: _authService.currentUser?.username,
      user: _authService.currentUser,
    );
    if (next != state) state = next;
  }

  void setLoggedIn(String username) {
    _authService.setLoggedIn(username);
    _syncStateFromService();
  }

  Future<String?> login(String username, String password) async {
    final error = await _authService.login(username, password);
    if (error == null) {
      await _applyLoginSuccess();
    }
    return error;
  }

  Future<void> refreshProfile() async {
    final user = await _authService.fetchProfile();
    if (user != null) {
      try {
        final next = state.copyWith(user: user, username: user.username);
        if (next != state) state = next;
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await ref.read(localDataProvider).flushPendingWrites();
    await _authService.logout();
    state = AuthState();
    ref.invalidate(forumListProvider);
  }

  /// Test helper: seed auth state without calling the network.
  void debugSetState(AuthState next) => state = next;
}

final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
