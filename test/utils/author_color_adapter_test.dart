import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/author_color_adapter.dart';
import 'package:s1er/utils/color_contrast.dart';

void main() {
  setUp(AuthorColorAdapter.clearCache);

  group('parseCssColor', () {
    test('parses hex and named colors', () {
      expect(
        AuthorColorAdapter.parseCssColor('#FF0000'),
        const Color(0xFFFF0000),
      );
      expect(AuthorColorAdapter.parseCssColor('#f00'), const Color(0xFFFF0000));
      expect(AuthorColorAdapter.parseCssColor('red'), const Color(0xFFFF0000));
      expect(AuthorColorAdapter.parseCssColor('Red'), const Color(0xFFFF0000));
      expect(AuthorColorAdapter.parseCssColor('not-a-color'), isNull);
    });
  });

  group('adaptPair', () {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.dark,
    );
    final lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.light,
    );

    test('lightens near-black text on dark surface', () {
      final adapted = AuthorColorAdapter.adaptPair(
        fg: Colors.black,
        surface: darkScheme.surface,
        onSurface: darkScheme.onSurface,
      );
      expect(adapted.fg, isNotNull);
      expect(
        ColorContrast.meetsTextContrast(adapted.fg!, darkScheme.surface),
        isTrue,
      );
      expect(adapted.fg, isNot(Colors.black));
    });

    test('keeps high-contrast pair unchanged', () {
      final adapted = AuthorColorAdapter.adaptPair(
        fg: Colors.black,
        bg: Colors.white,
        surface: lightScheme.surface,
        onSurface: lightScheme.onSurface,
      );
      expect(adapted.fg, Colors.black);
      expect(adapted.bg, Colors.white);
    });

    test('drops light background when pair stays unreadable', () {
      // Near-white text on near-white background — should drop bg and/or fg.
      final adapted = AuthorColorAdapter.adaptPair(
        fg: const Color(0xFFF5F5F5),
        bg: const Color(0xFFFFFFE0),
        surface: darkScheme.surface,
        onSurface: darkScheme.onSurface,
      );
      if (adapted.fg != null && adapted.bg != null) {
        expect(
          ColorContrast.meetsTextContrast(adapted.fg!, adapted.bg!),
          isTrue,
        );
      } else if (adapted.fg != null) {
        expect(
          ColorContrast.meetsTextContrast(adapted.fg!, darkScheme.surface),
          isTrue,
        );
        expect(adapted.bg, isNull);
      } else {
        expect(adapted.bg, isNull);
      }
    });

    test('preserves red hue roughly when lifting on dark surface', () {
      final adapted = AuthorColorAdapter.adaptPair(
        fg: const Color(0xFF800000),
        surface: darkScheme.surface,
        onSurface: darkScheme.onSurface,
      );
      expect(adapted.fg, isNotNull);
      final hsl = HSLColor.fromColor(adapted.fg!);
      // Maroon/red family stays in warm reds (hue near 0).
      expect(hsl.hue < 40 || hsl.hue > 320, isTrue);
      expect(
        ColorContrast.meetsTextContrast(adapted.fg!, darkScheme.surface),
        isTrue,
      );
    });
  });

  group('adaptHtml', () {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.dark,
    );

    test('returns identical string when no author colors', () {
      const html = '<p>plain <b>bold</b> text</p>';
      expect(AuthorColorAdapter.adaptHtml(html, darkScheme), html);
    });

    test('rewrites dark span color for dark surface', () {
      const html = '<span style="color:#000000">dark</span>';
      final out = AuthorColorAdapter.adaptHtml(html, darkScheme);
      expect(out, isNot(html));
      expect(out, contains('color:#'));
      expect(out, isNot(contains('color:#000000')));
      expect(out, contains('dark'));
    });

    test('adapts font color attribute', () {
      const html = '<font color="black">x</font>';
      final out = AuthorColorAdapter.adaptHtml(html, darkScheme);
      expect(out, contains('x'));
      // Either rewritten hex or removed (inherit onSurface).
      expect(out.contains('color="black"'), isFalse);
    });

    test('adapts background-color with foreground', () {
      const html =
          '<span style="color:#FFFFFF;background-color:#FFFFE0">hi</span>';
      final out = AuthorColorAdapter.adaptHtml(html, darkScheme);
      expect(out, contains('hi'));
      // Must not keep both near-white fg and near-white bg.
      final stillBad = out.contains('color:#FFFFFF') &&
          out.contains('background-color:#FFFFE0');
      expect(stillBad, isFalse);
    });
  });
}
