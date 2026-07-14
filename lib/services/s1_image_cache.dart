import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';

/// App-level image disk cache (Native).
///
/// Web keeps relying on the browser cache; this manager is still safe to call
/// for clear/size no-ops / IndexedDB-backed cache_manager behaviour.
class S1ImageCache {
  S1ImageCache._();

  static const String cacheKey = 's1ImageCache';
  static const Duration stalePeriod = Duration(days: 14);
  static const int maxNrOfCacheObjects = 500;
  static int _maxCacheBytesOverride = S1Constants.maxImageCacheBytes;

  static int get maxCacheBytes => _maxCacheBytesOverride;

  static void setMaxCacheBytes(int bytes) {
    _maxCacheBytesOverride = bytes;
  }

  @visibleForTesting
  static void debugResetMaxCacheBytes() {
    _maxCacheBytesOverride = S1Constants.maxImageCacheBytes;
  }

  /// Returns true when [url] exists in disk cache (native only).
  static Future<bool> hasCachedFile(String url) async {
    try {
      final info = await manager.getFileFromCache(url);
      return info != null;
    } catch (_) {
      return false;
    }
  }

  static CacheManager? _manager;

  /// Shared [CacheManager] used by CachedNetworkImage / Dio write-through.
  static CacheManager get manager {
    return _manager ??= CacheManager(
      Config(
        cacheKey,
        stalePeriod: stalePeriod,
        maxNrOfCacheObjects: maxNrOfCacheObjects,
      ),
    );
  }

  @visibleForTesting
  static void debugSetManager(CacheManager? value) {
    _manager = value;
  }

  /// Read cached bytes if present (disk). Returns null on miss / Web soft-fail.
  static Future<Uint8List?> getBytes(String url) async {
    try {
      final info = await manager.getFileFromCache(url);
      if (info == null) return null;
      return await info.file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Persist bytes fetched via Dio (auth / proxied images) into the same store.
  static Future<void> putBytes(String url, Uint8List bytes) async {
    try {
      await manager.putFile(
        url,
        bytes,
        maxAge: stalePeriod,
        fileExtension: extensionFromUrl(url) ?? 'bin',
      );
      await _evictToBudget();
    } catch (_) {
      // Disk cache is best-effort; callers still keep memory LRU.
    }
  }

  /// Clear disk cache + Flutter image memory pool.
  ///
  /// [clearMemoryLru] lets widgets flush their process-local byte maps.
  static Future<void> clear({void Function()? clearMemoryLru}) async {
    clearMemoryLru?.call();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await manager.emptyCache();
    } catch (_) {
      // Ignore platform / store errors; memory pools above are already cleared.
    }
  }

  /// Approximate on-disk size in bytes. Web returns 0 (browser-managed).
  static Future<int> approximateSizeBytes() async {
    if (kIsWeb) return 0;
    try {
      final cacheDir = await _cacheDirectory();
      if (cacheDir == null || !await cacheDir.exists()) return 0;
      return _directorySize(cacheDir);
    } catch (_) {
      return 0;
    }
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String formatLimit() => formatSize(maxCacheBytes);

  @visibleForTesting
  static String? extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    if (ext.isEmpty || ext.length > 5 || ext.contains('/')) return null;
    return ext;
  }

  static Future<Directory?> _cacheDirectory() async {
    if (kIsWeb) return null;
    try {
      final root = await getTemporaryDirectory();
      return Directory(p.join(root.path, cacheKey));
    } catch (_) {
      return null;
    }
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static Future<void> evictIfNeeded() => _evictToBudget();

  static Future<void> _evictToBudget() async {
    if (kIsWeb) return;
    final cacheDir = await _cacheDirectory();
    if (cacheDir == null || !await cacheDir.exists()) return;

    final files = <File>[];
    await for (final entity
        in cacheDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    if (total <= maxCacheBytes) return;

    files.sort(
      (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
    );

    for (final file in files) {
      if (total <= maxCacheBytes) break;
      try {
        total -= await file.length();
        await file.delete();
      } catch (_) {
        // Best-effort eviction.
      }
    }
  }
}
