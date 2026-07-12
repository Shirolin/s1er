import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/screens/compose_screen.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/compose_draft_store.dart';

void main() {
  final samplePost = Post(
    pid: '42',
    message: 'quoted content here',
    author: 'alice',
    authorId: '7',
    dateline: 1704067200,
    floor: 3,
  );

  testWidgets('ComposeScreen shows quote preview when draft is provided', (tester) async {
    final draftId = ComposeDraftStore.put(samplePost, displayFloor: 5);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: ComposeScreen(
            tid: '100',
            fid: '4',
            draftId: draftId,
            reppost: '42',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回复 #5 楼'), findsOneWidget);
    expect(find.textContaining('引用 #5 楼'), findsOneWidget);
    expect(find.textContaining('alice'), findsWidgets);
    expect(find.textContaining('quoted content'), findsOneWidget);
  });

  testWidgets('ComposeScreen redirects to login when not authenticated', (tester) async {
    final router = GoRouter(
      initialLocation: '/compose',
      routes: [
        GoRoute(
          path: '/compose',
          builder: (context, state) => const ComposeScreen(
            tid: '100',
            fid: '4',
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

    expect(find.text('Login Page'), findsOneWidget);
  });

  testWidgets('ComposeScreen without tid shows error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法回复'), findsOneWidget);
    expect(find.textContaining('仅支持回复已有主题'), findsOneWidget);
  });
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true, username: 'tester');
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}
