import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/s1_image_cache.dart';
import 'package:s1_app/widgets/image_viewer.dart';

/// In-memory [CacheInfoRepository] for unit tests (no path_provider).
class _MemoryCacheInfoRepository extends CacheInfoRepository {
  final Map<String, CacheObject> _byKey = {};
  int _nextId = 1;

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    final stored = cacheObject.copyWith(id: _nextId++);
    _byKey[stored.key] = stored;
    return stored;
  }

  @override
  Future<CacheObject?> get(String key) async => _byKey[key];

  @override
  Future<int> delete(int id) async {
    _byKey.removeWhere((_, obj) => obj.id == id);
    return 1;
  }

  @override
  Future<int> deleteAll(Iterable<int> ids) async {
    final idSet = ids.toSet();
    _byKey.removeWhere((_, obj) => idSet.contains(obj.id));
    return idSet.length;
  }

  @override
  Future<List<CacheObject>> getAllObjects() async => _byKey.values.toList();

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async => [];

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async => [];

  @override
  Future<bool> open() async => true;

  @override
  Future<bool> close() async => true;

  @override
  Future<int> update(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    if (cacheObject.id == null) return 0;
    _byKey[cacheObject.key] = cacheObject;
    return 1;
  }

  @override
  Future updateOrInsert(CacheObject cacheObject) async {
    if (cacheObject.id == null) {
      return insert(cacheObject);
    }
    return update(cacheObject);
  }

  @override
  Future<void> deleteDataFile() async {}

  @override
  Future<bool> exists() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    S1ImageCache.debugSetManager(null);
  });

  group('S1ImageCache.formatSize', () {
    test('formats bytes / KB / MB', () {
      expect(S1ImageCache.formatSize(0), '0 B');
      expect(S1ImageCache.formatSize(512), '512 B');
      expect(S1ImageCache.formatSize(2048), '2.0 KB');
      expect(S1ImageCache.formatSize(3 * 1024 * 1024), '3.0 MB');
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
      final manager = CacheManager(
        Config(
          's1ImageCacheMemoryTest',
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 20,
          repo: _MemoryCacheInfoRepository(),
          fileSystem: MemoryCacheSystem(),
        ),
      );
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
