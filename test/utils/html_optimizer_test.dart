import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:s1er/utils/html_optimizer.dart';

void main() {
  group('HtmlOptimizer Tests', () {
    tearDown(() {
      HtmlOptimizer.enableTagFlattening = true;
    });

    test('Merges adjacent font tags with identical attributes', () {
      const input =
          '<font color="#999">&nbsp;</font><font color="#999">&nbsp;&nbsp;</font>';
      final fragment = parseFragment(input);

      HtmlOptimizer.flatten(fragment);

      expect(
        fragment.outerHtml,
        equals('<font color="#999">&nbsp;&nbsp;&nbsp;</font>'),
      );
    });

    test('Does not merge adjacent font tags with different attributes', () {
      const input =
          '<font color="#999">&nbsp;</font><font color="#666">&nbsp;</font>';
      final fragment = parseFragment(input);

      HtmlOptimizer.flatten(fragment);

      expect(
        fragment.outerHtml,
        equals(
          '<font color="#999">&nbsp;</font><font color="#666">&nbsp;</font>',
        ),
      );
    });

    test('Does not merge tags when enableTagFlattening is false', () {
      HtmlOptimizer.enableTagFlattening = false;
      const input =
          '<font color="#999">&nbsp;</font><font color="#999">&nbsp;</font>';
      final fragment = parseFragment(input);

      HtmlOptimizer.flatten(fragment);

      expect(
        fragment.outerHtml,
        equals(
          '<font color="#999">&nbsp;</font><font color="#999">&nbsp;</font>',
        ),
      );
    });

    test('Recursively merges nested identical tags', () {
      const input =
          '<div><span class="a">Hello </span><span class="a">World</span></div>';
      final fragment = parseFragment(input);

      HtmlOptimizer.flatten(fragment);

      expect(
        fragment.outerHtml,
        equals('<div><span class="a">Hello World</span></div>'),
      );
    });
  });
}
