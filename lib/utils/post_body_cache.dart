/// 帖子正文（BBCode → HTML）的解析结果缓存策略。
///
/// 拥有「什么构成一次等价解析」的规则：正文文本 + 影响输出的渲染设置
/// （[showImages] / [maxImagesPerPost] / [quoteDepth]）。渲染 widget 不再
/// 自行拼装缓存键，只提供设置与惰性解析回调。
///
/// 本模块不依赖 Flutter / Riverpod：调用方读设置后传入，解析由 [build]
/// 回调注入（携带各自的 [PostImageIndexCounter]）。
library;

/// 一次正文解析的等价性键：正文 + 影响解析输出的设置。
class PostBodyCacheKey {
  const PostBodyCacheKey({
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
      other is PostBodyCacheKey &&
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

/// [PostBodyCache.htmlFor] 的结果：解析后的 HTML 及其来源。
class PostBodyCacheResult {
  const PostBodyCacheResult({required this.html, required this.wasCached});

  final String html;

  /// 为 true 表示来自缓存（本次未执行解析，副作用需由调用方重放）。
  final bool wasCached;
}

/// LRU 缓存 + 解析策略：命中返回缓存 HTML，未命中调用 [htmlFor] 的构造回调。
abstract final class PostBodyCache {
  static const int maxEntries = 200;

  static final _cache = <PostBodyCacheKey, String>{};
  static final _order = <PostBodyCacheKey>[];

  /// 返回该正文的 HTML 与来源：命中则直接返回；未命中则调用 [build] 生成并写入。
  ///
  /// [PostBodyCacheResult.wasCached] 供调用方决定是否重放解析副作用
  /// （如 [PostImageIndexCounter] 的图片计数）。
  static PostBodyCacheResult htmlFor({
    required PostBodyCacheKey key,
    required String Function() build,
  }) {
    final cached = _get(key);
    if (cached != null) {
      return PostBodyCacheResult(html: cached, wasCached: true);
    }
    final html = build();
    _put(key, html);
    return PostBodyCacheResult(html: html, wasCached: false);
  }

  static String? _get(PostBodyCacheKey key) {
    if (!_cache.containsKey(key)) return null;
    _order.remove(key);
    _order.add(key);
    return _cache[key];
  }

  static void _put(PostBodyCacheKey key, String html) {
    if (_cache.containsKey(key)) {
      _order.remove(key);
    } else if (_cache.length >= maxEntries) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = html;
    _order.add(key);
  }

  /// Test helper: clear all cached entries.
  static void clear() {
    _cache.clear();
    _order.clear();
  }
}
