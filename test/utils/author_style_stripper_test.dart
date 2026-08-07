import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/author_style_stripper.dart';

void main() {
  group('AuthorStyleStripper.strip', () {
    test('strips inline color/background/font-size, keeps other styles', () {
      const html =
          '<span style="color:#FF0000;background-color:#00FF00;font-size:24px;font-weight:bold">hi</span>';
      expect(
        AuthorStyleStripper.strip(html),
        '<span style="font-weight:bold">hi</span>',
      );
    });

    test('strips font color and size attributes', () {
      const html = '<font color="red" size="3">hello</font>';
      expect(AuthorStyleStripper.strip(html), '<font>hello</font>');
    });

    test('strips server-style font color', () {
      const html = '<font color="#336699">server text</font>';
      expect(AuthorStyleStripper.strip(html), '<font>server text</font>');
    });

    test('strips size-only style', () {
      const html = '<span style="font-size:20px">big</span>';
      expect(AuthorStyleStripper.strip(html), '<span>big</span>');
    });

    test('keeps semantic formatting and links untouched', () {
      const html = '<b>bold</b> <i>italic</i> <a href="x">link</a>';
      expect(AuthorStyleStripper.strip(html), html);
    });

    test('returns identical string when no author styles present', () {
      const html = '<p>plain</p><div>more</div>';
      expect(identical(AuthorStyleStripper.strip(html), html), isTrue);
    });

    test('strips nested styles recursively', () {
      const html =
          '<div style="color:red"><span style="background-color:blue">x</span></div>';
      expect(AuthorStyleStripper.strip(html), '<div><span>x</span></div>');
    });

    test('handles empty input', () {
      expect(AuthorStyleStripper.strip(''), isEmpty);
    });
  });
}
