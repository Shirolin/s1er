import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/utils/internal_navigation.dart';

void main() {
  testWidgets('same thread location replaces instead of pushing',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/thread/100?page=1',
      routes: [
        GoRoute(
          path: '/thread/:tid',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Text('tid=${state.pathParameters['tid']}'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.text('tid=100'));
    openInternalLocation(ctx, '/thread/100?pid=55');
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/thread/100?pid=55');
    expect(find.text('tid=100'), findsOneWidget);
  });

  testWidgets('different thread location pushes a new page', (tester) async {
    final router = GoRouter(
      initialLocation: '/thread/100',
      routes: [
        GoRoute(
          path: '/thread/:tid',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Text('tid=${state.pathParameters['tid']}'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.text('tid=100'));
    openInternalLocation(ctx, '/thread/200');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/thread/200');
    expect(router.canPop(), isTrue);
  });
}
