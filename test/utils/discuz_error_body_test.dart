import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/discuz_error_body.dart';

void main() {
  group('summarizeErrorBody', () {
    test('strips scripts, styles and tags into one line', () {
      const body = '''
<!DOCTYPE html>
<html><head><title>stage1st.com - System Error</title>
<style>body { color: black; }</style>
<script>alert(1)</script></head>
<body>
  <div class="tip">  System Error
    请稍后再试 </div>
</body></html>
''';
      final summary = summarizeErrorBody(body);
      expect(summary, contains('System Error'));
      expect(summary, contains('请稍后再试'));
      expect(summary, isNot(contains('<')));
      expect(summary, isNot(contains('alert(1)')));
      expect(summary, isNot(contains('color: black')));
      expect(summary, isNot(contains('  ')));
    });

    test('truncates long bodies', () {
      final summary = summarizeErrorBody('a' * 500);
      expect(summary.length, 161);
      expect(summary.endsWith('…'), isTrue);
    });

    test('empty body yields empty summary', () {
      expect(summarizeErrorBody('   '), isEmpty);
    });

    test('System Error page keeps the PHP message after BackTraceID', () {
      const body = '<title>stage1st.com - System Error</title>'
          'Discuz! System Error Time: 2026-10-26 15:58:55 +0800 '
          'IP: 1.2.3.4 BackTraceID: a35e7b78662ff27dc11565c0d8a577f8 '
          'in_array(): Argument #2 (\$haystack) must be of type array, null given '
          'PHP Debug No. File Line Code 1 api/mobile/index.php 17 ...';
      final summary = summarizeErrorBody(body);
      expect(
        summary,
        'in_array(): Argument #2 (\$haystack) must be of type array, null given',
      );
    });

    test('System Error without PHP Debug falls back to truncated text', () {
      const body = 'Discuz! System Error Time: now IP: 1.2.3.4 '
          'BackTraceID: abcdef in_array(): bad argument';
      expect(summarizeErrorBody(body), 'in_array(): bad argument');
    });
  });

  group('looksLikeDiscuzSecurityReject', () {
    test('detects request_tainting', () {
      expect(looksLikeDiscuzSecurityReject('...request_tainting...'), isTrue);
    });

    test('detects 非法字符', () {
      expect(looksLikeDiscuzSecurityReject('您的请求含有非法字符'), isTrue);
    });

    test('plain System Error page is not a security reject', () {
      expect(
        looksLikeDiscuzSecurityReject(
          '<title>stage1st.com - System Error</title>',
        ),
        isFalse,
      );
    });
  });
}
