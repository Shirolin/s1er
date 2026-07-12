import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/favorite_list_provider.dart';
import 'package:s1_app/providers/favorite_membership_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/providers/talker_provider.dart';
import 'package:s1_app/screens/favorites_screen.dart';
import 'package:s1_app/screens/profile_screen.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/theme/app_theme.dart';

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

  group('ProfileScreen favorites entry', () {
    testWidgets('shows favorites entry when logged in', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testUser = User(uid: '426519', username: 'TestUser');
      late _TestAuthNotifier mockNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            authStateProvider.overrideWith(() {
              mockNotifier = _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: testUser.username,
                  user: testUser,
                ),
              );
              return mockNotifier;
            }),
            packageInfoOverride(),
            favoriteListProvider(FavoriteSegment.all).overrideWith(
              () => _EmptyFavoriteListNotifier(FavoriteSegment.all),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的收藏'), findsOneWidget);
      expect(find.text('收藏的帖子与版块'), findsOneWidget);
    });

    testWidgets('hides favorites entry when logged out', (tester) async {
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

      expect(find.text('我的收藏'), findsNothing);
    });
  });

  group('FavoritesScreen', () {
    testWidgets('shows tab bar and empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...localOverrides(),
            packageInfoOverride(),
            authStateProvider.overrideWith(
              () => _TestAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  username: 'u',
                  user: User(uid: '1', username: 'u'),
                ),
              ),
            ),
            favoriteListProvider(FavoriteSegment.all).overrideWith(
              () => _EmptyFavoriteListNotifier(FavoriteSegment.all),
            ),
            favoriteListProvider(FavoriteSegment.thread).overrideWith(
              () => _EmptyFavoriteListNotifier(FavoriteSegment.thread),
            ),
            favoriteListProvider(FavoriteSegment.forum).overrideWith(
              () => _EmptyFavoriteListNotifier(FavoriteSegment.forum),
            ),
            favoriteMembershipProvider.overrideWith(
              () => _EmptyMembershipNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('帖子'), findsOneWidget);
      expect(find.text('板块'), findsOneWidget);
      expect(find.text('暂无收藏'), findsOneWidget);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _EmptyFavoriteListNotifier extends FavoriteListNotifier {
  _EmptyFavoriteListNotifier(super.segment);

  @override
  Future<FavoriteListState> build() async {
    return FavoriteListState();
  }
}

class _EmptyMembershipNotifier extends FavoriteMembershipNotifier {
  @override
  FavoriteMembershipState build() => const FavoriteMembershipState();
}
