import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/models/favorite_item.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/favorite_membership_provider.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/favorite_bookmark_button.dart';

void main() {
  testWidgets('FavoriteBookmarkButton redirects to login when logged out',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/forum',
      routes: [
        GoRoute(
          path: '/forum',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              elevation: 0,
              actions: const [
                FavoriteBookmarkButton(
                  type: FavoriteType.forum,
                  id: '4',
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Login Page')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('Login Page'), findsOneWidget);
  });

  testWidgets('FavoriteBookmarkButton shows filled icon when favorited',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          favoriteMembershipProvider.overrideWith(
            () => _FavoritedMembershipNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: FavoriteBookmarkButton(
              type: FavoriteType.thread,
              id: '123',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byTooltip('取消收藏'), findsOneWidget);
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
        username: 'alice',
        user: User(uid: '1', username: 'alice'),
      );
}

class _FavoritedMembershipNotifier extends FavoriteMembershipNotifier {
  @override
  FavoriteMembershipState build() {
    return const FavoriteMembershipState(
      keys: {'thread:123'},
    );
  }

  @override
  Future<void> ensureSynced() async {}
}
