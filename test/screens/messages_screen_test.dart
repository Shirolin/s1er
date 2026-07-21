import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/providers/messages_segment_provider.dart';
import 'package:s1er/screens/messages_screen.dart';
import '../helpers/messages_test_helpers.dart';
import '../helpers/test_theme.dart';

void main() {
  testWidgets('MessagesScreen shows notice list by default', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: messagesProviderOverrides(),
        child: wrapWithAppTheme(const MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的消息'), findsOneWidget);
    expect(find.text('我的提醒'), findsOneWidget);
    expect(find.text('JOJOROY'), findsOneWidget);
    expect(find.text('我对 Kiyohara_Yasuke 说'), findsNothing);
  });

  testWidgets('MessagesScreen switches to pm list segment', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: messagesProviderOverrides(),
        child: wrapWithAppTheme(const MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的消息'));
    await tester.pumpAndSettle();

    expect(find.text('我对 Kiyohara_Yasuke 说'), findsOneWidget);
    expect(find.text('JOJOROY'), findsNothing);
  });

  testWidgets('MessagesScreen updates messagesSegmentProvider', (tester) async {
    late int segment;
    await tester.pumpWidget(
      ProviderScope(
        overrides: messagesProviderOverrides(),
        child: wrapWithAppTheme(
          Consumer(
            builder: (context, ref, _) {
              segment = ref.watch(messagesSegmentProvider);
              return const MessagesScreen();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(segment, 0);

    await tester.tap(find.text('我的消息'));
    await tester.pumpAndSettle();

    expect(segment, 1);
  });

  testWidgets('notice tap navigates to thread route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: MessagesScreen(),
          ),
        ),
        GoRoute(
          path: '/thread/:tid',
          builder: (context, state) {
            final pid = state.uri.queryParameters['pid'];
            return Scaffold(
              body: Text('thread ${state.pathParameters['tid']} pid=$pid'),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: messagesProviderOverrides(),
        child: MaterialApp.router(
          theme: ThemeData(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('JOJOROY'));
    await tester.pumpAndSettle();

    expect(find.text('thread 2253488 pid=69899250'), findsOneWidget);
  });

  testWidgets('pm tap navigates to in-app conversation route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: MessagesScreen()),
        ),
        GoRoute(
          path: '/pm/:touid',
          builder: (context, state) => Scaffold(
            body: Text(
              'pm ${state.pathParameters['touid']} '
              '${state.uri.queryParameters['name']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: messagesProviderOverrides(),
        child: MaterialApp.router(
          theme: ThemeData(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我对 Kiyohara_Yasuke 说'));
    await tester.pumpAndSettle();

    expect(find.text('pm 535036 Kiyohara_Yasuke'), findsOneWidget);
  });
}
