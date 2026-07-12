import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/bbcode_parser.dart';

void main() {
  group('BbcodeParser post images', () {
    test('preserves anchor href and img src from div.img', () {
      final html = File('test/fixtures/post_images/stage1st_anchor.html')
          .readAsStringSync();
      final parsed = BbcodeParser.parse(html);

      expect(parsed, contains('class="post-image"'));
      expect(parsed, contains('data-preview='));
      expect(parsed, contains('.thumb.jpg'));
      expect(parsed, contains('data-full='));
      expect(parsed, contains('185034y9rw9og8zgzdgct8.png"'));
      expect(parsed, isNot(contains('<img')));
    });

    test('external single-url div.img becomes post-image with same preview/full',
        () {
      final html = File('test/fixtures/post_images/external_single.html')
          .readAsStringSync();
      final parsed = BbcodeParser.parse(html);

      expect(parsed, contains('class="post-image"'));
      expect(parsed, contains('data-preview="https://p.sda1.dev/'));
      expect(parsed, contains('data-full="https://p.sda1.dev/'));
    });

    test('[img] bbcode resolves to post-image span', () {
      const src = 'https://img.stage1st.com/forum/2024/01/a.png';
      final parsed = BbcodeParser.parse('[img]$src[/img]');

      expect(parsed, contains('class="post-image"'));
      expect(parsed, contains('data-preview="$src.thumb.jpg"'));
      expect(parsed, contains('data-full="$src"'));
    });

    test('extractImages reads data-preview attributes', () {
      const html =
          '<span class="post-image" data-preview="https://a/p.jpg" data-full="https://a/f.jpg"></span>';
      expect(BbcodeParser.extractImages(html), ['https://a/p.jpg']);
    });
  });
}
