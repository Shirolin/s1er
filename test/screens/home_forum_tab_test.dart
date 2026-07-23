import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/favorite_item.dart';
import 'package:s1er/models/forum_category.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/favorite_forum_pins_provider.dart';
import 'package:s1er/providers/favorite_membership_provider.dart';
import 'package:s1er/providers/forum_list_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/home_screen.dart';
import 'package:s1er/theme/app_theme.dart';

import '../helpers/messages_test_helpers.dart';

void main() {
  testWidgets('home forum tab hides blocked forums', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          forumListProvider.overrideWith(_TwoForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(hiddenForums: {'2'}),
            ),
          ),
          favoriteForumPinsProvider.overrideWith(_EmptyPinsNotifier.new),
          ...messagesProviderOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('外野'), findsOneWidget);
    expect(find.text('动漫论坛'), findsNothing);
    expect(find.text('已收藏'), findsNothing);
  });

  testWidgets('logged-in home shows favorite pin section', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          forumListProvider.overrideWith(_TwoForumListNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
          favoriteForumPinsProvider.overrideWith(_PinnedForumNotifier.new),
          favoriteMembershipProvider.overrideWith(_EmptyMembershipNotifier.new),
          ...messagesProviderOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('已收藏'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
    // Pinned + category list both show 外野.
    expect(find.text('外野'), findsNWidgets(2));
    expect(find.text('动漫论坛'), findsOneWidget);
  });
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        username: 'tester',
        user: User(uid: '1', username: 'tester'),
      );
}

class _EmptyMembershipNotifier extends FavoriteMembershipNotifier {
  @override
  FavoriteMembershipState build() => const FavoriteMembershipState();

  @override
  Future<void> ensureSynced() async {}

  @override
  Future<void> sync() async {}
}

class _TwoForumListNotifier extends ForumListNotifier {
  @override
  Future<List<ForumCategory>> build() async {
    return [
      ForumCategory(
        fid: 'c1',
        name: '分类',
        description: '',
        threads: 1,
        posts: 1,
        subforums: [
          ForumCategory(
            fid: '1',
            name: '外野',
            description: 'desc',
            threads: 10,
            posts: 10,
            todayPosts: 2,
          ),
          ForumCategory(
            fid: '2',
            name: '动漫论坛',
            description: '',
            threads: 5,
            posts: 5,
          ),
        ],
      ),
    ];
  }
}

class _EmptyPinsNotifier extends FavoriteForumPinsNotifier {
  @override
  Future<List<FavoriteItem>> build() async => const [];
}

class _PinnedForumNotifier extends FavoriteForumPinsNotifier {
  @override
  Future<List<FavoriteItem>> build() async {
    return const [
      FavoriteItem(
        favid: 'f1',
        type: FavoriteType.forum,
        id: '1',
        title: '外野',
        dateline: 100,
      ),
    ];
  }
}
