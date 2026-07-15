import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/providers/talker_provider.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/screens/profile_screen.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> localOverrides() => [
        localDataProvider.overrideWithValue(local),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            store: local.settings,
            initial: const AppSettings(),
          ),
        ),
      ];

  Override packageInfoOverride() => packageInfoProvider.overrideWith(
        (_) async => PackageInfo(
          appName: 'S1',
          packageName: 'com.example.s1',
          version: '1.0.0',
          buildNumber: '1',
        ),
      );

  group('ProfileScreen', () {
    testWidgets('GitHub mark has a transparent background', (tester) async {
      await tester.runAsync(() async {
        final data = await rootBundle.load(
          'assets/branding/github_mark.png',
        );
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        try {
          final pixels = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );

          expect(pixels, isNotNull);
          expect(pixels!.getUint8(3), 0);
          final visibleAlphaOffset =
              ((100 * frame.image.width + frame.image.width ~/ 2) * 4) + 3;
          expect(pixels.getUint8(visibleAlphaOffset), greaterThan(200));
        } finally {
          frame.image.dispose();
          codec.dispose();
        }
      });
    });

    testWidgets('shows settings entry tile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题、文字大小与显示'), findsOneWidget);
      expect(find.text('主题设置'), findsNothing);
    });

    testWidgets('guest sees dark room but not daily sign', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('小黑屋'), findsOneWidget);
      expect(find.text('每日签到'), findsNothing);
    });

    testWidgets('logged-in profile shows sign card and friends stats',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoOverride(),
            authStateProvider.overrideWith(
              () => _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: User(uid: '123', username: 'TestUser', friends: 3),
                ),
                shouldFail: false,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('每日签到'), findsOneWidget);
      expect(find.text('签到'), findsOneWidget);
      expect(find.text('好友'), findsOneWidget);
      expect(find.text('小黑屋'), findsOneWidget);
    });

    testWidgets('shows project support links and opens their URLs',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final openedUrls = <Uri>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: ProfileScreen(
              externalUrlLauncher: (uri) async {
                openedUrls.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('支持项目'), findsOneWidget);
      expect(find.text('爱发电'), findsOneWidget);
      expect(find.text('Ko-fi'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('查看项目源代码（即将开源）'), findsOneWidget);
      expect(find.byKey(const Key('github-mark')), findsOneWidget);

      await tester.tap(find.text('爱发电'));
      await tester.pump();
      await tester.tap(find.text('Ko-fi'));
      await tester.pump();
      await tester.tap(find.text('GitHub'));
      await tester.pump();

      expect(
        openedUrls,
        [
          Uri.parse('https://ifdian.net/a/shirolin'),
          Uri.parse('https://ko-fi.com/shirolin'),
          Uri.parse('https://github.com/Shirolin/s1-app'),
        ],
      );
    });

    testWidgets('shows feedback when a project support link cannot open',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: ProfileScreen(
              externalUrlLauncher: (_) async => false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('GitHub'));
      await tester.pump();

      expect(find.text('无法打开链接'), findsOneWidget);
    });

    testWidgets('shows confirm dialog when clicking logout and can cancel',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testUser = User(uid: '123', username: 'TestUser');
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith(() {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: testUser,
                ),
                shouldFail: false,
              );
              return mockNotifier;
            }),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logoutButton = find.text('退出登录');
      expect(logoutButton, findsOneWidget);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(find.text('确认退出'), findsOneWidget);
      expect(find.text('确定要退出登录吗？'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('确认退出'), findsNothing);
      expect(find.text('TestUser'), findsOneWidget);
      expect(mockNotifier.logoutCalled, false);
    });

    testWidgets(
        'logout successfully shows progress and changes page to logged out state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testUser = User(uid: '123', username: 'TestUser');
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith(() {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: testUser,
                ),
                shouldFail: false,
              );
              return mockNotifier;
            }),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出登录').last);

      await tester.pump();
      expect(find.text('正在退出登录…'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('已退出登录'), findsOneWidget);
      expect(find.text('未登录'), findsOneWidget);
      expect(find.text('TestUser'), findsNothing);
      expect(mockNotifier.logoutCalled, true);
    });

    testWidgets('logout failed keeps login state and shows error SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testUser = User(uid: '123', username: 'TestUser');
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith(() {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: testUser,
                ),
                shouldFail: true,
              );
              return mockNotifier;
            }),
            packageInfoOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出登录').last);

      await tester.pump();
      expect(find.text('正在退出登录…'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('退出失败: Exception: Network Error'), findsOneWidget);
      expect(find.text('TestUser'), findsOneWidget);
      expect(mockNotifier.logoutCalled, true);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initial, {required this.shouldFail});

  final AuthState initial;
  final bool shouldFail;
  bool logoutCalled = false;

  @override
  AuthState build() => initial;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldFail) {
      throw Exception('Network Error');
    }
    state = AuthState(isLoggedIn: false);
  }
}
