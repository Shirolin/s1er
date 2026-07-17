import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/blacklist_record.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/blacklist_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/user_profile_sheet.dart';

User _sampleUser() => User(
      uid: '123',
      username: '测试用户',
      groupTitle: '用户组',
      credits: 102910,
      posts: 5256,
      combat: 563,
      deadfish: 40,
      regdate: '2019-3-19 11:02:33',
      oltime: 100,
      following: 10,
      follower: 20,
    );

List<Override> _baseOverrides({
  required AuthNotifier Function() auth,
  BlacklistNotifier Function()? blacklist,
}) {
  return [
    settingsProvider.overrideWith(
      () => SettingsNotifier(initial: const AppSettings()),
    ),
    authStateProvider.overrideWith(auth),
    blacklistProvider.overrideWith(
      blacklist ?? _EmptyBlacklistNotifier.new,
    ),
  ];
}

void main() {
  testWidgets('showUserProfileSheet renders stats and details', (tester) async {
    final user = _sampleUser();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(auth: _LoggedOutAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showUserProfileSheet(
                  context,
                  future: Future.value(user),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('用户组'), findsOneWidget);
    expect(find.text('积分'), findsOneWidget);
    expect(find.text('死鱼'), findsOneWidget);
    expect(find.text('10万'), findsOneWidget);
    expect(find.text('注册时间'), findsOneWidget);
    expect(find.text('2019-3-19 11:02'), findsOneWidget);
    expect(find.text('Ta的帖子'), findsNothing);
    expect(find.text('发消息'), findsNothing);
  });

  testWidgets('logged-in other user shows 发消息 and not Ta的帖子', (tester) async {
    final user = _sampleUser();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: FilledButton(
              onPressed: () => showUserProfileSheet(
                context,
                future: Future.value(user),
                onFilterByAuthor: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/pm/:touid',
          builder: (context, state) => Scaffold(
            body: Text(
              'pm ${state.pathParameters['touid']} '
              'name=${state.uri.queryParameters['name']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('只看该作者'), findsOneWidget);
    expect(find.text('Ta的帖子'), findsNothing);

    await tester.tap(find.text('发消息'));
    await tester.pumpAndSettle();

    expect(find.text('pm 123 name=测试用户'), findsOneWidget);
  });

  testWidgets('posts stat navigates to user-space', (tester) async {
    final user = _sampleUser();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: FilledButton(
              onPressed: () => showUserProfileSheet(
                context,
                future: Future.value(user),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/user-space/:uid',
          builder: (context, state) => Scaffold(
            body: Text(
              'space ${state.pathParameters['uid']} '
              'username=${state.uri.queryParameters['username']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(auth: _LoggedOutAuthNotifier.new),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('帖子'));
    await tester.pumpAndSettle();

    expect(
      find.text('space 123 username=测试用户'),
      findsOneWidget,
    );
  });

  testWidgets('filter-only shows 只看该作者 when logged out', (tester) async {
    final user = _sampleUser();
    var filtered = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(auth: _LoggedOutAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showUserProfileSheet(
                  context,
                  future: Future.value(user),
                  onFilterByAuthor: () => filtered = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('只看该作者'), findsOneWidget);
    expect(find.text('发消息'), findsNothing);

    await tester.tap(find.text('只看该作者'));
    await tester.pumpAndSettle();

    expect(filtered, isTrue);
  });

  testWidgets('pm-blocked user hides 发消息', (tester) async {
    final user = _sampleUser();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(
          auth: _LoggedInAuthNotifier.new,
          blacklist: _PmBlockedBlacklistNotifier.new,
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showUserProfileSheet(
                  context,
                  future: Future.value(user),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发消息'), findsNothing);
  });
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true, username: '本地用户');
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _EmptyBlacklistNotifier extends BlacklistNotifier {
  @override
  List<BlacklistRecord> build() => const [];
}

class _PmBlockedBlacklistNotifier extends BlacklistNotifier {
  @override
  List<BlacklistRecord> build() => const [
        BlacklistRecord(
          uid: '123',
          username: '测试用户',
          createdAt: 0,
          scope: [BlacklistRecord.scopePm],
        ),
      ];
}
