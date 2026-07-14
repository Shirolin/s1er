import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/s1_image_cache.dart';

final imageCacheSizeProvider = FutureProvider.autoDispose<int>((ref) {
  return S1ImageCache.approximateSizeBytes();
});

CacheManager get s1ImageCacheManager => S1ImageCache.manager;

String formatImageCacheSize(int bytes) => S1ImageCache.formatSize(bytes);

Future<Uint8List?> getCachedImageBytes(String url) => S1ImageCache.getBytes(url);

Future<bool> hasCachedImage(String url) => S1ImageCache.hasCachedFile(url);

Future<void> evictImageCacheIfNeeded() => S1ImageCache.evictIfNeeded();

Future<void> clearS1ImageCaches({void Function()? clearMemoryLru}) {
  return S1ImageCache.clear(clearMemoryLru: clearMemoryLru);
}
