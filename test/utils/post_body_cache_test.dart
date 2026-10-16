import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/post_body_cache.dart';

void main() {
  setUp(PostBodyCache.clear);

  test('PostBodyCacheKey changes when showImages changes', () {
    const a = PostBodyCacheKey(
      message: 'hello',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 0,
    );
    const b = PostBodyCacheKey(
      message: 'hello',
      showImages: false,
      maxImagesPerPost: 5,
      quoteDepth: 0,
    );
    expect(a, isNot(equals(b)));
  });

  test('PostBodyCacheKey changes when maxImagesPerPost changes', () {
    const a = PostBodyCacheKey(
      message: 'hello',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 0,
    );
    const b = PostBodyCacheKey(
      message: 'hello',
      showImages: true,
      maxImagesPerPost: 10,
      quoteDepth: 0,
    );
    expect(a, isNot(equals(b)));
  });

  test('PostBodyCacheKey equal and hashCode works correctly', () {
    const a = PostBodyCacheKey(
      message: 'msg',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );
    const b = PostBodyCacheKey(
      message: 'msg',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );
    const c = PostBodyCacheKey(
      message: 'msg_diff',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  test('htmlFor builds on miss and returns cached on hit', () {
    var builds = 0;
    final first = PostBodyCache.htmlFor(
      key: const PostBodyCacheKey(
        message: 'hello',
        showImages: true,
        maxImagesPerPost: 5,
        quoteDepth: 0,
      ),
      build: () {
        builds++;
        return '<p>once</p>';
      },
    );
    expect(first.wasCached, isFalse);
    expect(first.html, '<p>once</p>');
    expect(builds, 1);

    final second = PostBodyCache.htmlFor(
      key: const PostBodyCacheKey(
        message: 'hello',
        showImages: true,
        maxImagesPerPost: 5,
        quoteDepth: 0,
      ),
      build: () {
        builds++;
        return '<p>should-not-run</p>';
      },
    );
    expect(second.wasCached, isTrue);
    expect(second.html, '<p>once</p>');
    expect(builds, 1);
  });

  test('htmlFor distinguishes settings in the key', () {
    PostBodyCache.htmlFor(
      key: const PostBodyCacheKey(
        message: 'hello',
        showImages: true,
        maxImagesPerPost: 5,
        quoteDepth: 0,
      ),
      build: () => 'with-images',
    );
    final other = PostBodyCache.htmlFor(
      key: const PostBodyCacheKey(
        message: 'hello',
        showImages: false,
        maxImagesPerPost: 5,
        quoteDepth: 0,
      ),
      build: () => 'without-images',
    );
    expect(other.wasCached, isFalse);
    expect(other.html, 'without-images');
  });

  test('evicts oldest entry when over capacity', () {
    for (var i = 0; i < PostBodyCache.maxEntries + 1; i++) {
      PostBodyCache.htmlFor(
        key: PostBodyCacheKey(
          message: 'key$i',
          showImages: true,
          maxImagesPerPost: 0,
          quoteDepth: 0,
        ),
        build: () => 'html$i',
      );
    }
    // key0 被淘汰 → 再次请求会重新 build。
    final revived = PostBodyCache.htmlFor(
      key: const PostBodyCacheKey(
        message: 'key0',
        showImages: true,
        maxImagesPerPost: 0,
        quoteDepth: 0,
      ),
      build: () => 'rebuilt',
    );
    expect(revived.wasCached, isFalse);
    expect(revived.html, 'rebuilt');

    // 最近的 key 仍命中。
    final recent = PostBodyCache.htmlFor(
      key: const PostBodyCacheKey(
        message: 'key${PostBodyCache.maxEntries}',
        showImages: true,
        maxImagesPerPost: 0,
        quoteDepth: 0,
      ),
      build: () => 'should-not-run',
    );
    expect(recent.wasCached, isTrue);
    expect(recent.html, 'html${PostBodyCache.maxEntries}');
  });
}
