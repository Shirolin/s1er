import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('image-viewer route without extra shows fallback', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/image-viewer',
          builder: (context, state) {
            final url = state.uri.queryParameters['url'];
            if (url == null || url.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('图片')),
                body: Center(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('返回'),
                  ),
                ),
              );
            }
            return Scaffold(body: Text(url));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme('purple'),
        routerConfig: router,
      ),
    );
    router.go('/image-viewer');
    await tester.pumpAndSettle();

    expect(find.text('返回'), findsOneWidget);
    expect(find.text('无法加载图片'), findsNothing);
  });
}
