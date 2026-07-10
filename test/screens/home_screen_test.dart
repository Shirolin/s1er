import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/forum_category.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/forum_list_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/screens/home_screen.dart';
import 'package:s1_app/services/auth_service.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  testWidgets('guest can view forum list on home forum tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(AppSettings()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('请先登录'), findsNothing);
    expect(find.text('主论坛'), findsOneWidget);
    expect(find.text('游戏论坛'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}

class _GuestForumListNotifier extends ForumListNotifier {
  @override
  Future<List<ForumCategory>> build() async {
    return [
      ForumCategory(
        fid: '1',
        name: '主论坛',
        description: '',
        threads: 100,
        posts: 500,
        subforums: [
          ForumCategory(
            fid: '4',
            name: '游戏论坛',
            description: '游戏文化，原创，新闻',
            threads: 100,
            posts: 500,
          ),
        ],
      ),
    ];
  }
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  _LoggedOutAuthNotifier(Ref ref) : super(_FakeAuthService(), ref) {
    state = AuthState();
  }
}

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  bool get isLoggedIn => false;

  @override
  void setLoggedIn(String username) {}

  @override
  Future<String?> login(String username, String password) async => null;

  @override
  Future<User?> fetchProfile() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<bool> checkSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
