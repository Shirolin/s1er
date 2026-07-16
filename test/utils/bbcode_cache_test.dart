import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/bbcode_cache.dart';

void main() {
  setUp(BbcodeCache.clear);

  test('put and get returns cached html', () {
    const key = 'k1';
    BbcodeCache.put(key, '<p>hello</p>');
    expect(BbcodeCache.get(key), '<p>hello</p>');
  });

  test('evicts oldest entry when over capacity', () {
    for (var i = 0; i < BbcodeCache.maxEntries + 1; i++) {
      BbcodeCache.put('key$i', 'html$i');
    }
    expect(BbcodeCache.get('key0'), isNull);
    expect(BbcodeCache.get('key1'), 'html1');
    expect(
      BbcodeCache.get('key${BbcodeCache.maxEntries}'),
      'html${BbcodeCache.maxEntries}',
    );
  });

  test('buildKey changes when settings change', () {
    const message = 'hello';
    final a = BbcodeCache.buildKey(
      message: message,
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 0,
    );
    final b = BbcodeCache.buildKey(
      message: message,
      showImages: false,
      maxImagesPerPost: 5,
      quoteDepth: 0,
    );
    expect(a, isNot(equals(b)));
  });

  test('buildKey changes when maxImagesPerPost changes', () {
    const message = 'hello';
    final a = BbcodeCache.buildKey(
      message: message,
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 0,
    );
    final b = BbcodeCache.buildKey(
      message: message,
      showImages: true,
      maxImagesPerPost: 10,
      quoteDepth: 0,
    );
    expect(a, isNot(equals(b)));
  });

  test('BbcodeCacheKey equal and hashCode works correctly', () {
    final a = BbcodeCache.buildKey(
      message: 'msg',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );
    final b = BbcodeCache.buildKey(
      message: 'msg',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );
    final c = BbcodeCache.buildKey(
      message: 'msg_diff',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  test('BbcodeCache uses BbcodeCacheKey for hit and miss', () {
    final keyA = BbcodeCache.buildKey(
      message: 'hello',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );
    final keyB = BbcodeCache.buildKey(
      message: 'hello',
      showImages: true,
      maxImagesPerPost: 5,
      quoteDepth: 1,
    );

    BbcodeCache.put(keyA, 'cached_html');
    expect(BbcodeCache.get(keyB), equals('cached_html'));
  });
}
