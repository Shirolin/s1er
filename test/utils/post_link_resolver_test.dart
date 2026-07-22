import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/post_link_resolver.dart';

void main() {
  group('PostLinkResolver', () {
    test('maps current, www and historical thread hosts to App routes', () {
      for (final host in [
        'stage1st.com',
        'www.stage1st.com',
        'bbs.stage1st.com',
        'saraba1st.com',
        'www.saraba1st.com',
        'bbs.saraba1st.com',
      ]) {
        final result = PostLinkResolver.resolve(
          'https://$host/2b/forum.php?mod=viewthread&tid=123&page=2',
        );
        expect(result, isA<InternalPostLink>());
        expect((result as InternalPostLink).location, '/thread/123?page=2');
      }
    });

    test('maps legacy read.php / viewthread.php / read-htm-tid tid links', () {
      expect(
        _location('http://bbs.saraba1st.com/2b/read.php?tid=842562'),
        '/thread/842562',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/read-htm-tid-742087.html',
        ),
        '/thread/742087',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/read-htm-tid-742087-page-2.html',
        ),
        '/thread/742087?page=2',
      );
      expect(
        _location(
          'https://bbs.stage1st.com/2b/viewthread.php?tid=123&page=2&pid=456',
        ),
        '/thread/123?pid=456',
      );
    });

    test('decodes double &amp;amp; and strips messy Discuz tid suffixes', () {
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&amp;amp;tid=606858.html',
        ),
        '/thread/606858',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com//2b/forum.php?mod=viewthread&amp;amp;tid=911581-page-1.html',
        ),
        '/thread/911581?page=1',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&amp;amp;tid=874342-fpage-3-page-2.html',
        ),
        '/thread/874342?page=2',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&amp;amp;tid=562154-.html',
        ),
        '/thread/562154',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com//2b/forum.php?mod=viewthread&amp;amp;tid=912331.htm',
        ),
        '/thread/912331',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com//2b/forum.php?mod=viewthread&amp;amp;tid=918850-fpage-2.html',
        ),
        '/thread/918850',
      );
    });

    test('maps bare numeric fragments as pid (legacy Discuz anchors)', () {
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/read.php?tid=731672&amp;amp;page=2#16352875',
        ),
        '/thread/731672?pid=16352875',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&amp;amp;tid=899431-page-2.html#20770218',
        ),
        '/thread/899431?pid=20770218',
      );
      expect(
        _location('http://bbs.saraba1st.com/2b/read.php?tid=675176#14653317'),
        '/thread/675176?pid=14653317',
      );
    });

    test('ignores non-pid fragments like #a / #tpc', () {
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&amp;amp;tid=928599-page-1.html#tpc',
        ),
        '/thread/928599?page=1',
      );
      expect(
        _location(
          'http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&amp;amp;tid=604195-page-e.html#a',
        ),
        '/thread/604195',
      );
    });

    test('maps relative, protocol-relative and rewritten thread links', () {
      expect(
        _location('forum.php?mod=viewthread&amp;tid=123&amp;page=2'),
        '/thread/123?page=2',
      );
      expect(
        _location('//bbs.stage1st.com/2b/thread-123-3-1.html'),
        '/thread/123?page=3',
      );
    });

    test('prioritizes post targets over page and supports pid fragments', () {
      expect(
        _location('forum.php?mod=redirect&goto=findpost&ptid=123&pid=456'),
        '/thread/123?pid=456',
      );
      expect(
        _location(
          'https://stage1st.com/2b/forum.php?mod=viewthread&tid=123&page=2#pid789',
        ),
        '/thread/123?pid=789',
      );
    });

    test('maps first forum page and user-space tabs', () {
      expect(_location('forum-4-1.html'), '/forum/4');
      expect(
        _location('home.php?mod=space&uid=42&do=thread&type=reply'),
        '/user-space/42?tab=1',
      );
    });

    test(
        'uses external fallback for unsupported forum pages and external hosts',
        () {
      final forumPage = PostLinkResolver.resolve('forum-4-2.html');
      expect(forumPage, isA<ExternalPostLink>());
      expect((forumPage as ExternalPostLink).uri.host, 'stage1st.com');

      final external = PostLinkResolver.resolve('https://example.com/hello');
      expect(external, isA<ExternalPostLink>());
      expect((external as ExternalPostLink).uri.host, 'example.com');

      // 历史帖里的拼写错误域名，不应硬猜成站内。
      final typo = PostLinkResolver.resolve(
        'http://www.sarabalst.com/2b/read.php?tid=844143',
      );
      expect(typo, isA<ExternalPostLink>());
    });

    test('rejects dangerous schemes for external launch', () {
      for (final url in [
        'javascript:alert(1)',
        'intent://evil#Intent;scheme=https;end',
        'file:///etc/passwd',
        'data:text/html,hi',
      ]) {
        expect(
          PostLinkResolver.resolve(url),
          isA<InvalidPostLink>(),
          reason: url,
        );
      }
    });

    test('allows mailto as external link', () {
      final result = PostLinkResolver.resolve('mailto:user@example.com');
      expect(result, isA<ExternalPostLink>());
      expect((result as ExternalPostLink).uri.scheme, 'mailto');
    });
  });
}

String _location(String url) {
  final result = PostLinkResolver.resolve(url);
  expect(result, isA<InternalPostLink>(), reason: url);
  return (result as InternalPostLink).location;
}
