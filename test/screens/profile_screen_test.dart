import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/providers/talker_provider.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/services/auth_service.dart';
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
          (ref) => SettingsNotifier(
            store: local.settings,
            initial: const AppSettings(),
          ),
        ),
      ];

  group('ProfileScreen', () {
    testWidgets('shows settings entry tile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
              ),
            ),
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

    testWidgets('shows confirm dialog when clicking logout and can cancel',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testUser = User(uid: '123', username: 'TestUser');
      final mockService = _FakeAuthService();
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith((ref) {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: testUser,
                ),
                mockService,
                ref,
              );
              return mockNotifier;
            }),
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
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
      final mockService = _FakeAuthService();
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith((ref) {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: testUser,
                ),
                mockService,
                ref,
              );
              return mockNotifier;
            }),
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
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
      final mockService = _FakeAuthService(shouldFail: true);
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith((ref) {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'TestUser',
                  user: testUser,
                ),
                mockService,
                ref,
              );
              return mockNotifier;
            }),
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
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
  _TestAuthNotifier(this.initial, this.service, Ref ref) : super(service, ref) {
    state = initial;
  }

  final AuthState initial;
  final _FakeAuthService service;
  bool logoutCalled = false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (service.shouldFail) {
      throw Exception('Network Error');
    }
    state = AuthState(isLoggedIn: false);
  }
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.shouldFail = false});
  final bool shouldFail;

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
  Future<bool> checkSession() {
    return Future.value(false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
