/// Represents a unique cache key for BBCode rendering to avoid hash collisions.
class BbcodeCacheKey {
  const BbcodeCacheKey({
    required this.message,
    required this.showImages,
    required this.maxImagesPerPost,
    required this.quoteDepth,
  });

  final String message;
  final bool showImages;
  final int maxImagesPerPost;
  final int quoteDepth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BbcodeCacheKey &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          showImages == other.showImages &&
          maxImagesPerPost == other.maxImagesPerPost &&
          quoteDepth == other.quoteDepth;

  @override
  int get hashCode => Object.hash(
        message,
        showImages,
        maxImagesPerPost,
        quoteDepth,
      );
}

/// LRU cache for BBCode → HTML conversion results.
class BbcodeCache {
  BbcodeCache._();

  static const int maxEntries = 200;

  static final _cache = <Object, String>{};
  static final _order = <Object>[];

  static String? get(Object key) {
    if (!_cache.containsKey(key)) return null;
    _order.remove(key);
    _order.add(key);
    return _cache[key];
  }

  static void put(Object key, String html) {
    if (_cache.containsKey(key)) {
      _order.remove(key);
    } else if (_cache.length >= maxEntries) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = html;
    _order.add(key);
  }

  /// Builds a cache key from message identity and render settings.
  static BbcodeCacheKey buildKey({
    required String message,
    required bool showImages,
    required int maxImagesPerPost,
    required int quoteDepth,
  }) {
    return BbcodeCacheKey(
      message: message,
      showImages: showImages,
      maxImagesPerPost: maxImagesPerPost,
      quoteDepth: quoteDepth,
    );
  }

  /// Test helper: clear all cached entries.
  static void clear() {
    _cache.clear();
    _order.clear();
  }
}
