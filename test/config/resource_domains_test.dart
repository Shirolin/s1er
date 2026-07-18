import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/resource_domains.dart';

void main() {
  group('ResourceDomains.isForumHost', () {
    test('recognizes current and historical forum hosts', () {
      expect(ResourceDomains.isForumHost('stage1st.com'), isTrue);
      expect(ResourceDomains.isForumHost('WWW.Stage1st.COM'), isTrue);
      expect(ResourceDomains.isForumHost('bbs.stage1st.com'), isTrue);
      expect(ResourceDomains.isForumHost('bbs.saraba1st.com'), isTrue);
      expect(ResourceDomains.isForumHost('www.saraba1st.com'), isTrue);
      expect(ResourceDomains.isForumHost('saraba1st.com'), isTrue);
    });

    test('does not treat CDN or lookalike hosts as forum pages', () {
      expect(ResourceDomains.isForumHost('img.stage1st.com'), isFalse);
      expect(ResourceDomains.isForumHost('app.saraba1st.com'), isFalse);
      expect(ResourceDomains.isForumHost('stage1st.com.evil.example'), isFalse);
    });
  });

  group('ResourceDomains.isAllowedProxyTarget', () {
    test('allows https auth image host', () {
      expect(
        ResourceDomains.isAllowedProxyTarget(
          Uri.parse('https://img.stage1st.com/avatar.jpg'),
        ),
        isTrue,
      );
    });

    test('allows https public asset host', () {
      expect(
        ResourceDomains.isAllowedProxyTarget(
          Uri.parse('https://static.stage1st.com/emoticon.gif'),
        ),
        isTrue,
      );
    });

    test('rejects http scheme', () {
      expect(
        ResourceDomains.isAllowedProxyTarget(
          Uri.parse('http://img.stage1st.com/a.jpg'),
        ),
        isFalse,
      );
    });

    test('rejects unknown host', () {
      expect(
        ResourceDomains.isAllowedProxyTarget(
          Uri.parse('https://evil.com/steal'),
        ),
        isFalse,
      );
    });

    test('rejects IP literal host', () {
      expect(
        ResourceDomains.isAllowedProxyTarget(
          Uri.parse('https://127.0.0.1/secret'),
        ),
        isFalse,
      );
    });

    test('rejects api host for img-proxy', () {
      expect(
        ResourceDomains.isAllowedProxyTarget(
          Uri.parse('https://stage1st.com/2b/api'),
        ),
        isFalse,
      );
    });
  });

  group('ResourceDomains.isAllowedImgProxyTarget', () {
    test('allows whitelisted hosts', () {
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('https://img.stage1st.com/avatar.jpg'),
        ),
        isTrue,
      );
    });

    test('allows explicit external image host p.sda1.dev', () {
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('https://p.sda1.dev/3/test.png'),
        ),
        isTrue,
      );
    });

    test('rejects unknown https hosts', () {
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('https://evil.example/x.png'),
        ),
        isFalse,
      );
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('https://stage1st.com/2b/api'),
        ),
        isFalse,
      );
    });

    test('rejects http scheme', () {
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('http://p.sda1.dev/test.png'),
        ),
        isFalse,
      );
    });

    test('rejects localhost and IPv6-like hosts', () {
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('https://localhost/test.png'),
        ),
        isFalse,
      );
      expect(
        ResourceDomains.isAllowedImgProxyTarget(
          Uri.parse('https://[::1]/secret'),
        ),
        isFalse,
      );
    });
  });
}
