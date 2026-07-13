/// LRU cache for BBCode → HTML conversion results.
class BbcodeCache {
  BbcodeCache._();

  static const int maxEntries = 200;

  static final _cache = <String, String>{};
  static final _order = <String>[];

  static String? get(String key) {
    if (!_cache.containsKey(key)) return null;
    _order.remove(key);
    _order.add(key);
    return _cache[key];
  }

  static void put(String key, String html) {
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
  static String buildKey({
    required String message,
    required bool showImages,
    required int maxImagesPerPost,
    required int quoteDepth,
  }) {
    return '${message.hashCode}|$showImages|$maxImagesPerPost|$quoteDepth';
  }

  /// Test helper: clear all cached entries.
  static void clear() {
    _cache.clear();
    _order.clear();
  }
}
