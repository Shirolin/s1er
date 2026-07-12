import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// In-memory [CacheInfoRepository] for unit tests (no path_provider).
class MemoryCacheInfoRepository extends CacheInfoRepository {
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

CacheManager createMemoryImageCacheManager(String cacheKey) {
  return CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 20,
      repo: MemoryCacheInfoRepository(),
      fileSystem: MemoryCacheSystem(),
    ),
  );
}
