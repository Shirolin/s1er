import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/forum_category.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/forum_list_provider.dart';
import 'package:s1_app/providers/messages_segment_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/screens/home_screen.dart';
import 'package:s1_app/services/auth_service.dart';
import 'package:s1_app/theme/app_theme.dart';
import '../helpers/messages_test_helpers.dart';

void main() {
  testWidgets('guest can view forum list on home forum tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(initial: const AppSettings()),
          ),
          ...messagesProviderOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('请先登录'), findsNothing);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
    expect(find.text('主论坛'), findsOneWidget);
    expect(find.text('游戏论坛'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('logged in home screen uses chinese labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(initial: const AppSettings()),
          ),
          ...messagesProviderOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('登录'), findsNothing);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
    expect(find.text('Messages'), findsNothing);

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('搜索'), findsNWidgets(2));
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    expect(find.text('消息'), findsNWidgets(2));
    expect(find.text('Messages'), findsNothing);
    expect(find.text('我的消息'), findsOneWidget);
    expect(find.text('我对 Kiyohara_Yasuke 说'), findsOneWidget);

    await tester.tap(find.text('我的提醒'));
    await tester.pumpAndSettle();
    expect(find.text('JOJOROY'), findsOneWidget);
    expect(messagesBrowserUrl(1), contains('do=notice'));
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

class _LoggedInAuthNotifier extends AuthNotifier {
  _LoggedInAuthNotifier(Ref ref) : super(_FakeAuthService(), ref) {
    state = AuthState(
      isLoggedIn: true,
      user: User(
        uid: '1',
        username: 'tester',
        avatar: '',
      ),
    );
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
