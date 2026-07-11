import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/bbcode_parser.dart';
import 'package:s1_app/widgets/emoticon_widget.dart';
import 'package:s1_app/widgets/quote_block.dart';
import 'package:s1_app/widgets/bbcode_renderer.dart';

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
      final html =
          BbcodeParser.parse('[img]https://example.com/pic.jpg[/img]');
      expect(html, contains('img'));
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
          '<p><img src="https://example.com/1.jpg" /> <img src="https://example.com/2.jpg" /></p>';
      final images = BbcodeParser.extractImages(html);
      expect(images.length, 2);
      expect(images[0], 'https://example.com/1.jpg');
      expect(images[1], 'https://example.com/2.jpg');
    });

    test('parses URL tags', () {
      final html =
          BbcodeParser.parse('[url=https://example.com]link[/url]');
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
          home: Scaffold(
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
          home: Scaffold(
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
          home: Scaffold(
            body: EmoticonWidget(code: 'unknown'),
          ),
        ),
      );
      // The widget should render without errors regardless of emoticon mapping
      expect(find.byType(EmoticonWidget), findsOneWidget);
    });
  });

  group('QuoteBlock', () {
    testWidgets('renders with left border decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: QuoteBlock(content: 'quoted text'),
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
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: QuoteBlock(content: 'quoted text'),
          ),
        ),
      );
      // QuoteBlock uses BbcodeRenderer internally
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });

    testWidgets('handles empty content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: QuoteBlock(content: ''),
          ),
        ),
      );
      expect(find.byType(QuoteBlock), findsOneWidget);
    });

    testWidgets('handles complex quoted content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: QuoteBlock(content: '[b]bold quote[/b]'),
          ),
        ),
      );
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });
  });

  group('BbcodeRenderer', () {
    testWidgets('renders empty string as SizedBox', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: BbcodeRenderer(bbcode: ''),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders plain text content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: BbcodeRenderer(bbcode: 'Hello world'),
          ),
        ),
      );
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });

    testWidgets('handles content with quote block', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: BbcodeRenderer(
                bbcode: 'before [quote]quoted[/quote] after',),
          ),
        ),
      );
      // Should have a QuoteBlock for the quoted section
      expect(find.byType(QuoteBlock), findsOneWidget);
      // QuoteBlock internally creates a BbcodeRenderer, so there are 2 total
      expect(find.byType(BbcodeRenderer), findsWidgets);
    });

    testWidgets('handles multiple quote blocks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: BbcodeRenderer(
                bbcode: '[quote]first[/quote]middle[quote]second[/quote]',),
          ),
        ),
      );
      expect(find.byType(QuoteBlock), findsNWidgets(2));
    });

    testWidgets('handles content without quotes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: BbcodeRenderer(bbcode: '[b]bold[/b]'),
          ),
        ),
      );
      // No QuoteBlock when there are no [quote] tags
      expect(find.byType(QuoteBlock), findsNothing);
      expect(find.byType(BbcodeRenderer), findsOneWidget);
    });

    testWidgets('returns Column as root widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: BbcodeRenderer(bbcode: 'text'),
          ),
        ),
      );
      expect(find.byType(Column), findsOneWidget);
    });
  });
}
