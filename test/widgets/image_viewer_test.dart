import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/image_load_policy.dart';
import 'package:s1_app/providers/connectivity_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/s1_image_cache.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/image_viewer.dart';

import '../helpers/memory_cache_info_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    S1ImageCache.debugSetManager(
      createMemoryImageCacheManager('s1ImageCacheWidgetTest'),
    );
  });

  tearDown(() {
    S1ImageCache.debugSetManager(null);
    ImageViewer.clearMemoryCache();
  });

  Future<void> pumpPolicyState(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
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

  testWidgets('ImageViewer accepts distinct preview and full URLs', (tester) async {
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

  testWidgets('ImageViewer shows tap placeholder in manual mode', (tester) async {
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
          home: const Scaffold(
            body: ImageViewer(
              imageUrl: 'https://example.com/image.jpg',
            ),
          ),
        ),
      ),
    );

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
  });
}
