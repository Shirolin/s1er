import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/constants.dart';
import 'package:s1_app/services/s1_image_cache.dart';
import 'package:s1_app/widgets/image_viewer.dart';

import '../helpers/memory_cache_info_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    S1ImageCache.debugResetEvictionScheduler();
    S1ImageCache.debugSetManager(null);
    S1ImageCache.debugResetMaxCacheBytes();
  });

  group('S1ImageCache.formatSize', () {
    test('formats bytes / KB / MB', () {
      expect(S1ImageCache.formatSize(0), '0 B');
      expect(S1ImageCache.formatSize(512), '512 B');
      expect(S1ImageCache.formatSize(2048), '2.0 KB');
      expect(S1ImageCache.formatSize(3 * 1024 * 1024), '3.0 MB');
    });

    test('formatLimit reflects configured cap', () {
      expect(
        S1ImageCache.formatLimit(),
        '${S1Constants.defaultImageCacheLimitMb}.0 MB',
      );
    });

    test('setMaxCacheBytes updates formatLimit', () {
      S1ImageCache.setMaxCacheBytes(100 * 1024 * 1024);
      expect(S1ImageCache.formatLimit(), '100.0 MB');
    });
  });

  group('S1ImageCache.extensionFromUrl', () {
    test('extracts common extensions', () {
      expect(
        S1ImageCache.extensionFromUrl('https://a.example/x/y.jpg'),
        'jpg',
      );
      expect(
        S1ImageCache.extensionFromUrl('https://a.example/x/y.PNG?q=1'),
        'png',
      );
    });

    test('returns null for missing or odd paths', () {
      expect(S1ImageCache.extensionFromUrl('https://a.example/x/y'), isNull);
      expect(
        S1ImageCache.extensionFromUrl('https://a.example/x/y.toolongext'),
        isNull,
      );
    });
  });

  group('S1ImageCache put/get/clear', () {
    test('round-trips bytes through CacheManager and clears', () async {
      final manager = createMemoryImageCacheManager('s1ImageCacheMemoryTest');
      addTearDown(() async {
        await manager.dispose();
      });
      S1ImageCache.debugSetManager(manager);

      const url = 'https://example.com/pic.jpg';
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      await S1ImageCache.putBytes(url, bytes);
      final loaded = await S1ImageCache.getBytes(url);
      expect(loaded, bytes);

      var cleared = false;
      await S1ImageCache.clear(clearMemoryLru: () => cleared = true);
      expect(cleared, isTrue);

      final afterClear = await S1ImageCache.getBytes(url);
      expect(afterClear, isNull);
    });
  });

  test('ImageViewer.clearMemoryCache is safe to call', () {
    ImageViewer.clearMemoryCache();
  });
}
