import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/screens/image_viewer_screen.dart';
import 'package:s1_app/theme/app_theme.dart';

// 1x1 transparent PNG
final _tinyPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('ImageViewerScreen shows back button and info action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: ImageViewerScreen(
            imageUrl: 'https://example.com/image.jpg',
            imageBytes: _tinyPng,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('图片信息'), findsOneWidget);
  });

  testWidgets('ImageViewerScreen pops when back is pressed', (tester) async {
    final router = GoRouter(
      initialLocation: '/viewer',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Previous Page')),
          ),
          routes: [
            GoRoute(
              path: 'viewer',
              builder: (context, state) => ImageViewerScreen(
                imageUrl: 'https://example.com/image.jpg',
                imageBytes: _tinyPng,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('Previous Page'), findsOneWidget);
  });
}

class _IdleAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}
