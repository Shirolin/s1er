import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/forum_category.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/forum_list_provider.dart';
import 'package:s1er/providers/forum_name_provider.dart';
import 'package:s1er/providers/messages_segment_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/home_screen.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import '../helpers/messages_test_helpers.dart';

void main() {
  testWidgets('empty forum list shows retry button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_EmptyForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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

    expect(find.text('暂无版块数据'), findsOneWidget);
    expect(find.text('请点击重试或下拉刷新'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('暂无版块数据'), findsOneWidget);
  });

  testWidgets('guest can view forum list on home forum tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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
    expect(find.text('动漫论坛'), findsOneWidget);
    expect(find.text('音乐论坛'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('expanded category shows all subforums', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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

    expect(find.text('游戏论坛'), findsOneWidget);
    expect(find.text('动漫论坛'), findsOneWidget);
    expect(find.text('音乐论坛'), findsOneWidget);
  });

  testWidgets('large forum layout lets both columns flow independently',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_UnevenForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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

    final leftSecond = tester.getTopLeft(find.text('左列第二组').first);
    final rightSecond = tester.getTopLeft(find.text('右列第二组').first);

    expect(leftSecond.dx, lessThan(rightSecond.dx));
    expect(
      leftSecond.dy,
      lessThan(rightSecond.dy),
      reason: '较短的左列应独立回流，不能再被右列高卡片撑出大段空白',
    );

    await tester.tap(find.text('右列第一组'));
    await tester.pumpAndSettle();
    final collapsedRightSecond = tester.getTopLeft(find.text('右列第二组').first);
    expect(
      collapsedRightSecond.dy,
      lessThan(rightSecond.dy),
      reason: '折叠右列分类后，右列后续分类应独立向上回流',
    );

    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpAndSettle();
    final compactLeftSecond = tester.getTopLeft(find.text('左列第二组').first);
    final compactRightSecond = tester.getTopLeft(find.text('右列第二组').first);
    expect(compactLeftSecond.dx, compactRightSecond.dx);
    expect(compactLeftSecond.dy, lessThan(compactRightSecond.dy));
  });

  testWidgets('logged in home screen uses chinese labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('搜索主题与帖子'), findsOneWidget);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    expect(find.text('消息'), findsNWidgets(2));
    expect(find.text('Messages'), findsNothing);
    expect(find.text('我的提醒'), findsOneWidget);
    expect(find.text('JOJOROY'), findsOneWidget);

    await tester.tap(find.text('我的消息'));
    await tester.pumpAndSettle();
    expect(find.text('我对 Kiyohara_Yasuke 说'), findsOneWidget);
    expect(messagesBrowserUrl(1), contains('do=pm'));
  });

  testWidgets('guest profile tab then login resets to forum tab without error',
      (tester) async {
    late _MutableAuthNotifier authNotifier;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final local = AppLocalData(db);
    await local.loadEssentials();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(() {
            authNotifier = _MutableAuthNotifier(AuthState());
            return authNotifier;
          }),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('登录'), findsWidgets);

    authNotifier.setState(
      AuthState(
        isLoggedIn: true,
        username: 'alice',
        user: User(uid: '1', username: 'alice'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Stage1st'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(
      find.byType(NavigationBar).evaluate().isNotEmpty ||
          find.byType(NavigationRail).evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected NavigationBar or NavigationRail to be present',
    );
  });

  testWidgets(
      'login then forum route does not dirty ProviderScope during Overlay build',
      (tester) async {
    late _MutableAuthNotifier authNotifier;
    late ProviderContainer container;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final local = AppLocalData(db);
    await local.loadEssentials();
    addTearDown(db.close);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/forum/:fid',
          builder: (_, state) => _ForumRouteProbe(
            fid: state.pathParameters['fid']!,
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, _) => _LoginTransitionScreen(
            onLogin: () {
              authNotifier.setState(
                AuthState(
                  isLoggedIn: true,
                  username: 'alice',
                  user: User(uid: '1', username: 'alice'),
                ),
              );
              container.invalidate(forumListProvider);
              context.go('/');
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(() {
            authNotifier = _MutableAuthNotifier(AuthState());
            return authNotifier;
          }),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
          ...messagesProviderOverrides(),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录').last);
    await tester.pumpAndSettle();
    expect(find.text('完成登录'), findsOneWidget);

    await tester.tap(find.text('完成登录'));
    expect(tester.takeException(), isNull, reason: '点击登录时不应同步报错');
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '认证状态重建时不应报错');
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Overlay 路由重建时不应报错');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '登录过渡完成后不应遗留异常');
    expect(find.text('Stage1st'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);

    await tester.tap(find.text('游戏论坛'));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '进入板块时不应触发 ProviderScope 异常',
    );
    expect(find.text('游戏论坛'), findsNWidgets(2));

    router.pop();
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '返回论坛首页时不应触发 ProviderScope 异常',
    );
    expect(find.text('Stage1st'), findsOneWidget);
  });

  testWidgets(
      'logout from logged-in profile tab resets guest tabs without error',
      (tester) async {
    late _MutableAuthNotifier authNotifier;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final local = AppLocalData(db);
    await local.loadEssentials();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(() {
            authNotifier = _MutableAuthNotifier(
              AuthState(
                isLoggedIn: true,
                username: 'alice',
                user: User(uid: '1', username: 'alice'),
              ),
            );
            return authNotifier;
          }),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    expect(find.text('我的消息'), findsOneWidget);

    authNotifier.setState(AuthState());
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('消息'), findsNothing);
  });

  testWidgets('profile tab refreshes when auth loads full user after login',
      (tester) async {
    late _MutableAuthNotifier authNotifier;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final local = AppLocalData(db);
    await local.loadEssentials();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(() {
            authNotifier = _MutableAuthNotifier(
              AuthState(isLoggedIn: true, username: 'Shirolin'),
            );
            return authNotifier;
          }),
          forumListProvider.overrideWith(_GuestForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
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

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('积分'), findsNothing);

    authNotifier.setState(
      AuthState(
        isLoggedIn: true,
        username: 'Shirolin',
        user: User(
          uid: '426519',
          username: 'Shirolin',
          credits: 1200,
          posts: 42,
          threads: 7,
          friends: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('积分'), findsOneWidget);
    expect(find.text('帖子'), findsOneWidget);
  });
}

class _EmptyForumListNotifier extends ForumListNotifier {
  @override
  Future<List<ForumCategory>> build() async => const [];
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
          ForumCategory(
            fid: '5',
            name: '动漫论坛',
            description: '',
            threads: 50,
            posts: 200,
          ),
          ForumCategory(
            fid: '6',
            name: '音乐论坛',
            description: '',
            threads: 30,
            posts: 120,
          ),
        ],
      ),
    ];
  }
}

class _UnevenForumListNotifier extends ForumListNotifier {
  @override
  Future<List<ForumCategory>> build() async {
    ForumCategory subforum(String fid) => ForumCategory(
          fid: fid,
          name: '版块 $fid',
          description: '说明',
          threads: 10,
          posts: 20,
        );

    return [
      ForumCategory(
        fid: 'left-1',
        name: '左列第一组',
        description: '',
        threads: 10,
        posts: 20,
        subforums: [subforum('1')],
      ),
      ForumCategory(
        fid: 'right-1',
        name: '右列第一组',
        description: '',
        threads: 10,
        posts: 20,
        subforums: [
          subforum('2'),
          subforum('3'),
          subforum('4'),
          subforum('5'),
          subforum('6'),
        ],
      ),
      ForumCategory(
        fid: 'left-2',
        name: '左列第二组',
        description: '',
        threads: 10,
        posts: 20,
      ),
      ForumCategory(
        fid: 'right-2',
        name: '右列第二组',
        description: '',
        threads: 10,
        posts: 20,
      ),
    ];
  }
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        user: User(
          uid: '1',
          username: 'tester',
          avatar: '',
        ),
      );
}

class _MutableAuthNotifier extends AuthNotifier {
  _MutableAuthNotifier(this._state);

  AuthState _state;

  @override
  AuthState build() => _state;

  void setState(AuthState next) {
    _state = next;
    state = next;
  }
}

class _LoginTransitionScreen extends StatelessWidget {
  const _LoginTransitionScreen({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('登录')),
      body: Center(
        child: FilledButton(
          onPressed: onLogin,
          child: const Text('完成登录'),
        ),
      ),
    );
  }
}

class _ForumRouteProbe extends ConsumerWidget {
  const _ForumRouteProbe({required this.fid});

  final String fid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forumName = ref.watch(forumNameProvider(fid));
    return Scaffold(
      appBar: AppBar(elevation: 0, title: Text(forumName ?? '版块')),
      body: Center(child: Text(forumName ?? '版块')),
    );
  }
}
