import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/post_link_resolver.dart';

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

    test('maps legacy read.php / viewthread.php tid links', () {
      expect(
        _location('http://bbs.saraba1st.com/2b/read.php?tid=842562'),
        '/thread/842562',
      );
      expect(
        _location(
          'https://bbs.stage1st.com/2b/viewthread.php?tid=123&page=2&pid=456',
        ),
        '/thread/123?pid=456',
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
    });
  });
}

String _location(String url) {
  final result = PostLinkResolver.resolve(url);
  expect(result, isA<InternalPostLink>());
  return (result as InternalPostLink).location;
}
