import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/providers/connectivity_provider.dart';
import 'package:s1er/providers/image_bytes_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/image_viewer_screen.dart';
import 'package:s1er/services/s1_image_cache.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/image_viewer.dart';

Uint8List _pngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 80, 80));
  return Uint8List.fromList(img.encodePng(image));
}

class _EmptyCacheManager implements CacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getFileFromCache) {
      return Future<FileInfo?>.value(null);
    }
    if (invocation.memberName == #getFileStream) {
      return const Stream<FileResponse>.empty();
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    S1ImageCache.debugSetManager(_EmptyCacheManager());
  });

  tearDown(() {
    S1ImageCache.debugSetManager(null);
    ImageViewer.clearMemoryCache();
  });

  group('ImageViewer full-screen pass-through', () {
    testWidgets(
      'does not pass preview bytes when preview and full URLs differ',
      (tester) async {
        const preview = 'https://img.stage1st.com/forum/a.png.thumb.jpg';
        const full = 'https://img.stage1st.com/forum/a.png';
        final previewBytes = _pngBytes(width: 40, height: 30);

        Map<String, dynamic>? pushedExtra;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: ImageViewer(
                  imageUrl: preview,
                  fullImageUrl: full,
                ),
              ),
            ),
            GoRoute(
              path: '/image-viewer',
              builder: (context, state) {
                if (state.extra is Map<String, dynamic>) {
                  pushedExtra = Map<String, dynamic>.from(
                    state.extra! as Map<String, dynamic>,
                  );
                }
                return const Scaffold(body: Text('viewer'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(
                () => SettingsNotifier(
                  initial: const AppSettings(showImages: true),
                ),
              ),
              wifiConnectedProvider.overrideWith((ref) async* {
                yield true;
              }),
              imageBytesProvider.overrideWith((ref, url) async {
                expect(url, preview);
                return previewBytes;
              }),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme('purple'),
              routerConfig: router,
            ),
          ),
        );

        // Allow async load + image frame decode.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.byType(Image), findsWidgets);
        await tester.tap(find.byType(Image).first);
        await tester.pumpAndSettle();

        expect(pushedExtra?['imageUrl'], full);
        expect(pushedExtra?['imageBytes'], isNull);
      },
    );

    testWidgets(
      'passes bytes when preview and full URLs are the same',
      (tester) async {
        const url = 'https://img.stage1st.com/forum/same.png';
        final bytes = _pngBytes(width: 40, height: 30);

        Map<String, dynamic>? pushedExtra;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: ImageViewer(imageUrl: url),
              ),
            ),
            GoRoute(
              path: '/image-viewer',
              builder: (context, state) {
                if (state.extra is Map<String, dynamic>) {
                  pushedExtra = Map<String, dynamic>.from(
                    state.extra! as Map<String, dynamic>,
                  );
                }
                return const Scaffold(body: Text('viewer'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(
                () => SettingsNotifier(
                  initial: const AppSettings(showImages: true),
                ),
              ),
              wifiConnectedProvider.overrideWith((ref) async* {
                yield true;
              }),
              imageBytesProvider.overrideWith((ref, u) async {
                expect(u, url);
                return bytes;
              }),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme('purple'),
              routerConfig: router,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.byType(Image), findsWidgets);
        await tester.tap(find.byType(Image).first);
        await tester.pumpAndSettle();

        expect(pushedExtra?['imageUrl'], url);
        expect(pushedExtra?['imageBytes'], same(bytes));
      },
    );
  });

  group('ImageViewerScreen', () {
    testWidgets('shows error and retries when bytes fetch fails',
        (tester) async {
      var attempts = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageBytesProvider.overrideWith((ref, url) async {
              attempts++;
              return null;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ImageViewerScreen(
              imageUrl: 'https://img.stage1st.com/forum/missing.png',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('加载失败，点击重试'), findsOneWidget);
      expect(attempts, 1);

      await tester.tap(find.text('加载失败，点击重试'));
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(find.text('加载失败，点击重试'), findsOneWidget);
    });

    testWidgets('fit / 1:1 / zoom step match scale semantics', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const imageW = 400;
      const imageH = 200;
      final bytes = _pngBytes(width: imageW, height: imageH);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: ImageViewerScreen(
              imageUrl: 'https://img.stage1st.com/forum/photo.png',
              imageBytes: bytes,
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;

      final contentSize = tester.getSize(find.byType(InteractiveViewer));
      final expectedFit = math.min(
        contentSize.width / imageW,
        contentSize.height / imageH,
      );

      expect(
        controller.value.getMaxScaleOnAxis(),
        closeTo(expectedFit, 0.05),
      );

      await tester.tap(find.byTooltip('原始大小'));
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
      expect(find.text('1:1'), findsOneWidget);

      await tester.tap(find.byTooltip('合适'));
      await tester.pump();
      expect(
        controller.value.getMaxScaleOnAxis(),
        closeTo(expectedFit, 0.05),
      );

      final beforeZoom = controller.value.getMaxScaleOnAxis();
      await tester.tap(find.byTooltip('放大'));
      await tester.pump();
      expect(
        controller.value.getMaxScaleOnAxis(),
        closeTo(beforeZoom * 1.5, 0.05),
      );

      await tester.tap(find.byTooltip('缩小'));
      await tester.pump();
      expect(
        controller.value.getMaxScaleOnAxis(),
        closeTo(beforeZoom, 0.05),
      );
    });

    testWidgets('fetches imageUrl when opened without bytes', (tester) async {
      final requested = <String>[];
      final bytes = _pngBytes(width: 80, height: 60);
      const full = 'https://img.stage1st.com/forum/full.png';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageBytesProvider.overrideWith((ref, url) async {
              requested.add(url);
              return bytes;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ImageViewerScreen(imageUrl: full),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(requested, [full]);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });
}
