import 'package:flutter_test/flutter_test.dart';

import '../../scripts/proxy_server.dart';

void main() {
  group('rewriteProxyLocation', () {
    final upstream = Uri.parse(
      'https://stage1st.com/2b/search.php?searchsubmit=yes&mod=forum',
    );

    test('rewrites a same-origin relative redirect through local proxy', () {
      final result = rewriteProxyLocation(
        '/2b/search.php?mod=forum&searchid=123',
        upstream,
      );

      expect(
        result,
        'http://localhost:19080/2b/search.php?mod=forum&searchid=123',
      );
    });

    test('rewrites a same-origin absolute redirect', () {
      final result = rewriteProxyLocation(
        'https://stage1st.com/2b/thread-1-1-1.html',
        upstream,
      );

      expect(result, 'http://localhost:19080/2b/thread-1-1-1.html');
    });

    test('rejects redirects to another host', () {
      expect(
        rewriteProxyLocation('https://example.com/path', upstream),
        isNull,
      );
    });

    test('ignores a missing location header', () {
      expect(rewriteProxyLocation(null, upstream), isNull);
    });
  });
}
