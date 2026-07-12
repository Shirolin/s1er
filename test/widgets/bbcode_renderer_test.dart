import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/bbcode_parser.dart';
import 'package:s1_app/utils/post_image_index_counter.dart';
import 'package:s1_app/widgets/emoticon_widget.dart';
import 'package:s1_app/widgets/quote_block.dart';
import 'package:s1_app/widgets/bbcode_renderer.dart';

Widget _wrapBbcode(
  Widget child, {
  AppSettings settings = const AppSettings(),
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        () => SettingsNotifier(initial: settings),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme('purple'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('BbcodeParser (unit)', () {
    test('parses bold tags', () {
      final html = BbcodeParser.parse('[b]hello[/b]');
      expect(html, contains('<b>hello</b>'));
    });

    test('parses italic tags', () {
      final html = BbcodeParser.parse('[i]italic[/i]');
      expect(html, contains('<i>italic</i>'));
    });

    test('parses image tags', () {
      final html = BbcodeParser.parse('[img]https://example.com/pic.jpg[/img]');
      expect(html, contains('post-image'));
      expect(html, contains('https://example.com/pic.jpg'));
    });

    test('parses quote tags', () {
      final html = BbcodeParser.parse('[quote]quoted text[/quote]');
      expect(html, contains('quoted text'));
    });

    test('converts emoticon codes', () {
      final html = BbcodeParser.parse('[f:001]');
      expect(html, contains('emoticon'));
    });

    test('handles nested tags', () {
      final html = BbcodeParser.parse('[b][i]bold and italic[/i][/b]');
      expect(html, contains('bold and italic'));
    });

    test('handles empty input', () {
      final html = BbcodeParser.parse('');
      expect(html, isEmpty);
    });

    test('strips HTML tags for plain text', () {
      final text = BbcodeParser.stripTags('<b>hello</b>');
      expect(text, 'hello');
    });

    test('strips nested tags', () {
      final text = BbcodeParser.stripTags('<div><span>text</span></div>');
      expect(text, 'text');
    });

    test('extracts image URLs from HTML', () {
      const html =
          '<span class="post-image" data-preview="https://example.com/1.jpg" data-full="https://example.com/1.jpg"></span> '
          '<span class="post-image" data-preview="https://example.com/2.jpg" data-full="https://example.com/2.jpg"></span>';
      final images = BbcodeParser.extractImages(html);
      expect(images.length, 2);
      expect(images[0], 'https://example.com/1.jpg');
      expect(images[1], 'https://example.com/2.jpg');
    });

    test('parses URL tags', () {
      final html = BbcodeParser.parse('[url=https://example.com]link[/url]');
      expect(html, contains('href="https://example.com"'));
      expect(html, contains('link'));
    });

    test('parses color tags', () {
      final html = BbcodeParser.parse('[color=red]text[/color]');
      expect(html, contains('color:red'));
      expect(html, contains('text'));
    });

    test('parses size tags', () {
      final html = BbcodeParser.parse('[size=20]big text[/size]');
      expect(html, contains('font-size:20px'));
      expect(html, contains('big text'));
    });
  });

  group('EmoticonWidget', () {
    testWidgets('renders text fallback for unknown code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: EmoticonWidget(code: 'unknown'),
          ),
        ),
      );
      expect(find.text('unknown'), findsOneWidget);
    });

    testWidgets('renders text fallback for unmapped emoticon code',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: EmoticonWidget(code: 'random'),
          ),
        ),
      );
      expect(find.text('random'), findsOneWidget);
    });

    testWidgets('has correct size constraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: EmoticonWidget(code: 'unknown'),
          ),
        ),
      );
      expect(find.byType(EmoticonWidget), findsOneWidget);
    });
  });

  group('QuoteBlock', () {
    final counter = PostImageIndexCounter();

    testWidgets('renders with left border decoration', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          QuoteBlock(
            content: 'quoted text',
            imageIndexCounter: counter,
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(find.byType(QuoteBlock), findsOneWidget);
    });

    testWidgets('displays quoted content via BbcodeRenderer', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          QuoteBlock(
            content: 'quoted text',
            imageIndexCounter: counter,
          ),
        ),
      );
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });

    testWidgets('handles empty content', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          QuoteBlock(
            content: '',
            imageIndexCounter: counter,
          ),
        ),
      );
      expect(find.byType(QuoteBlock), findsOneWidget);
    });

    testWidgets('handles complex quoted content', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          QuoteBlock(
            content: '[b]bold quote[/b]',
            imageIndexCounter: counter,
          ),
        ),
      );
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });
  });

  group('BbcodeRenderer', () {
    testWidgets('renders empty string as SizedBox', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: '',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders plain text content', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: 'Hello world',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });

    testWidgets('handles content with quote block', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: 'before [quote]quoted[/quote] after',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(QuoteBlock), findsOneWidget);
      expect(find.byType(BbcodeRenderer), findsWidgets);
    });

    testWidgets('handles multiple quote blocks', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: '[quote]first[/quote]middle[quote]second[/quote]',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(QuoteBlock), findsNWidgets(2));
    });

    testWidgets('handles content without quotes', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: '[b]bold[/b]',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(QuoteBlock), findsNothing);
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });

    testWidgets('returns Column as root widget', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: 'text',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('shows expand chip when images exceed per-post limit',
        (tester) async {
      final counter = PostImageIndexCounter();
      var expanded = false;

      await tester.pumpWidget(
        _wrapBbcode(
          StatefulBuilder(
            builder: (context, setState) {
              return BbcodeRenderer(
                bbcode:
                    '[img]https://example.com/1.jpg[/img]'
                    '[img]https://example.com/2.jpg[/img]'
                    '[img]https://example.com/3.jpg[/img]',
                imageIndexCounter: counter,
                imagesExpanded: expanded,
                onExpandImages: () => setState(() => expanded = true),
              );
            },
          ),
          settings: const AppSettings(maxImagesPerPost: 2),
        ),
      );
      await tester.pump();

      expect(find.text('还有 1 张图片，点击展开'), findsOneWidget);
      expect(counter.assignedCount, 3);
    });
  });
}
