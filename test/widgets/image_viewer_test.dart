import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/image_load_policy.dart';
import 'package:s1er/providers/connectivity_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/s1_image_cache.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/image_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    S1ImageCache.debugSetManager(_FakeCacheManager());
  });

  tearDown(() {
    S1ImageCache.debugSetManager(null);
    ImageViewer.clearMemoryCache();
  });

  Future<void> pumpPolicyState(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('ImageViewer shows placeholder when showImages is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showImages: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: ImageViewer(
              imageUrl: 'https://example.com/image.jpg',
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('[图片]'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ImageViewer still renders emoticon when showImages is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showImages: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: ImageViewer(
              imageUrl:
                  'https://avatar.stage1st.com/000/00/00/01_avatar_small.jpg',
              isEmoticon: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('[图片]'), findsNothing);
  });

  testWidgets('ImageViewer accepts distinct preview and full URLs',
      (tester) async {
    const preview = 'https://img.stage1st.com/forum/a.png.thumb.jpg';
    const full = 'https://img.stage1st.com/forum/a.png';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: ImageViewer(
              imageUrl: preview,
              fullImageUrl: full,
            ),
          ),
        ),
      ),
    );

    final viewer = tester.widget<ImageViewer>(find.byType(ImageViewer));
    expect(viewer.imageUrl, preview);
    expect(viewer.fullImageUrl, full);
  });

  testWidgets('ImageViewer shows tap placeholder in manual mode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                showImages: true,
                imageLoadPolicy: ImageLoadPolicy.manual,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: ImageViewer(
              imageUrl: 'https://example.com/image.jpg',
            ),
          ),
        ),
      ),
    );

    await pumpPolicyState(tester);

    expect(find.text('点击加载图片'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final region = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(ImageViewer),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(region.cursor, SystemMouseCursors.click);
  });

  testWidgets('ImageViewer auto-loads on wifi when policy is wifiOnly',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                showImages: true,
                imageLoadPolicy: ImageLoadPolicy.wifiOnly,
              ),
            ),
          ),
          wifiConnectedProvider.overrideWith((ref) async* {
            yield true;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: _TestWrapper(
              builder: (context, showReal) {
                if (!showReal) return const SizedBox();
                return const ImageViewer(
                  imageUrl: 'https://example.com/image.jpg',
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    tester.state<_TestWrapperState>(find.byType(_TestWrapper)).toggle();
    await tester.pump();

    await pumpPolicyState(tester);

    expect(find.text('点击加载图片'), findsNothing);
  });

  testWidgets('ImageViewer defers load on cellular when policy is wifiOnly',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                showImages: true,
                imageLoadPolicy: ImageLoadPolicy.wifiOnly,
              ),
            ),
          ),
          wifiConnectedProvider.overrideWith((ref) async* {
            yield false;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: _TestWrapper(
              builder: (context, showReal) {
                if (!showReal) return const SizedBox();
                return const ImageViewer(
                  imageUrl: 'https://example.com/image.jpg',
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    tester.state<_TestWrapperState>(find.byType(_TestWrapper)).toggle();
    await tester.pump();

    await pumpPolicyState(tester);

    expect(find.text('点击加载图片'), findsOneWidget);
  });

  testWidgets('ImageViewer defers load until visible when deferUntilVisible',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                showImages: true,
                imageLoadPolicy: ImageLoadPolicy.always,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: ListView(
              children: [
                const SizedBox(height: 800),
                const ImageViewer(
                  imageUrl: 'https://example.com/offscreen.jpg',
                  deferUntilVisible: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    await tester.pump();

    expect(find.text('点击加载图片'), findsNothing);
  });

  testWidgets('block ImageViewer centers within content; emoticon stays inline',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showImages: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImageViewer(
                    imageUrl: 'https://example.com/post.jpg',
                    showBorder: true,
                  ),
                  ImageViewer(
                    imageUrl:
                        'https://avatar.stage1st.com/000/00/00/01_avatar_small.jpg',
                    isEmoticon: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final block = find.ancestor(
      of: find.text('[图片]'),
      matching: find.byType(Align),
    );
    expect(block, findsWidgets);
    expect(
      tester.widget<Align>(block.first).alignment,
      Alignment.center,
    );

    final emoticon = find.byWidgetPredicate(
      (w) =>
          w is ImageViewer &&
          w.isEmoticon &&
          w.imageUrl.contains('avatar_small'),
    );
    expect(
      find.descendant(of: emoticon, matching: find.byType(Align)),
      findsNothing,
    );
  });

  testWidgets('block ImageViewer respects compact full width on phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showImages: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: ImageViewer(
                imageUrl: 'https://example.com/post.jpg',
                showBorder: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final constrained = find.descendant(
      of: find.byType(ImageViewer),
      matching: find.byType(ConstrainedBox),
    );
    expect(constrained, findsWidgets);
    final maxWidth =
        tester.widget<ConstrainedBox>(constrained.first).constraints.maxWidth;
    expect(maxWidth, 360);
  });
}

class _FakeCacheManager implements CacheManager {
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

class _TestWrapper extends ConsumerStatefulWidget {
  const _TestWrapper({required this.builder});
  final Widget Function(BuildContext context, bool showReal) builder;

  @override
  ConsumerState<_TestWrapper> createState() => _TestWrapperState();
}

class _TestWrapperState extends ConsumerState<_TestWrapper> {
  bool _showReal = false;

  void toggle() => setState(() => _showReal = true);

  @override
  Widget build(BuildContext context) {
    // Eagerly watch to ensure the stream starts emitting immediately
    ref.watch(wifiConnectedProvider);
    return widget.builder(context, _showReal);
  }
}
