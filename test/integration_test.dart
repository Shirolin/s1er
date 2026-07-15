import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/thread.dart';
import 'package:s1_app/utils/bbcode_parser.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('Full Integration', () {
    test('Thread model roundtrip', () {
      final thread = Thread(
        tid: '123',
        subject: 'Test Subject',
        author: 'author',
        authorId: '1',
        dateline: 1700000000,
        views: 100,
        replies: 10,
        fid: '4',
      );

      final json = thread.toJson();
      final restored = Thread.fromJson(json);

      expect(restored.tid, thread.tid);
      expect(restored.subject, thread.subject);
      expect(restored.views, thread.views);
    });

    test('BBCode full conversion', () {
      const input =
          '[b]Bold[/b] [i]Italic[/i] [img]http://test.com/pic.jpg[/img]';
      final html = BbcodeParser.parse(input);

      expect(html, contains('<b>Bold</b>'));
      expect(html, contains('<i>Italic</i>'));
      expect(html, contains('post-image'));
      expect(html, contains('http://test.com/pic.jpg'));
    });

    test('API URL construction', () {
      final url = ApiService.buildApiUrl(
        module: 'forumdisplay',
        params: {'fid': '4', 'page': '1'},
      );

      expect(url, contains('module=forumdisplay'));
      expect(url, contains('fid=4'));
      expect(url, contains('version=4'));
    });
  });
}
