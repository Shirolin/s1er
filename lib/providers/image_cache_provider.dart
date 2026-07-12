import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/s1_image_cache.dart';
import '../widgets/image_viewer.dart';

/// Approximate image disk-cache size; invalidate after clear.
final imageCacheSizeProvider = FutureProvider.autoDispose<int>((ref) {
  return S1ImageCache.approximateSizeBytes();
});

Future<void> clearS1ImageCaches() {
  return S1ImageCache.clear(clearMemoryLru: ImageViewer.clearMemoryCache);
}
