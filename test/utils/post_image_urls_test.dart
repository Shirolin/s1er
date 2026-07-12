import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/post_image_urls.dart';

void main() {
  group('PostImageUrls.resolve', () {
    test('uses anchor href as full when distinct from img src', () {
      const src =
          'https://img.stage1st.com/forum/202411/12/foo.png.thumb.jpg';
      const href =
          'https://img.stage1st.com/forum/202411/12/foo.png';

      final urls = PostImageUrls.resolve(src: src, linkHref: href);

      expect(urls.previewUrl, src);
      expect(urls.fullUrl, href);
      expect(urls.hasDistinctFull, isTrue);
    });

    test('ignores javascript anchor href', () {
      const src = 'https://example.com/a.jpg';
      final urls = PostImageUrls.resolve(
        src: src,
        linkHref: 'javascript:;',
      );

      expect(urls.previewUrl, src);
      expect(urls.fullUrl, src);
    });

    test('derives full URL from .thumb.jpg suffix', () {
      const src =
          'https://img.stage1st.com/forum/202411/12/foo.png.thumb.jpg';
      final urls = PostImageUrls.resolve(src: src);

      expect(urls.previewUrl, src);
      expect(
        urls.fullUrl,
        'https://img.stage1st.com/forum/202411/12/foo.png',
      );
    });

    test('derives preview from img.stage1st.com forum attachment', () {
      const src = 'https://img.stage1st.com/forum/202411/12/foo.png';
      final urls = PostImageUrls.resolve(src: src);

      expect(urls.previewUrl, '$src.thumb.jpg');
      expect(urls.fullUrl, src);
      expect(urls.hasDistinctFull, isTrue);
    });

    test('single external URL falls back to same preview and full', () {
      const src =
          'https://p.sda1.dev/7/207f88594e49ab8df0811b84220771da/IMG.jpg';
      final urls = PostImageUrls.resolve(src: src);

      expect(urls.previewUrl, src);
      expect(urls.fullUrl, src);
      expect(urls.hasDistinctFull, isFalse);
    });

    test('normalizes HTML-escaped ampersands in href', () {
      const src = 'https://img.stage1st.com/forum/a.png.thumb.jpg';
      const href =
          'https://stage1st.com/2b/forum.php?mod=image&amp;aid=123&amp;size=source';
      final urls = PostImageUrls.resolve(src: src, linkHref: href);

      expect(urls.fullUrl, contains('mod=image'));
      expect(urls.fullUrl, contains('aid=123'));
      expect(urls.fullUrl, isNot(contains('&amp;')));
    });
  });
}
