import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/resource_domains.dart';

void main() {
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
}
