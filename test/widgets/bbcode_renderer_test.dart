import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/bbcode_parser.dart';
import 'package:s1er/utils/post_image_index_counter.dart';
import 'package:s1er/widgets/emoticon_widget.dart';
import 'package:s1er/widgets/quote_block.dart';
import 'package:s1er/widgets/bbcode_renderer.dart';

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
      theme: AppTheme.lightTheme(settings.themeColor),
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

    testWidgets('wraps top-level content in SelectionArea', (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: 'text',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('nested quote renderer does not add another SelectionArea',
        (tester) async {
      await tester.pumpWidget(
        _wrapBbcode(
          BbcodeRenderer(
            bbcode: 'before [quote]quoted[/quote] after',
            imageIndexCounter: PostImageIndexCounter(),
          ),
        ),
      );
      // Outer BbcodeRenderer + QuoteBlock's nested BbcodeRenderer → only one
      // SelectionArea at depth 0.
      expect(find.byType(BbcodeRenderer), findsWidgets);
      expect(find.byType(QuoteBlock), findsOneWidget);
      expect(find.byType(SelectionArea), findsOneWidget);
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
                bbcode: '[img]https://example.com/1.jpg[/img]'
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

      final chip = find.widgetWithText(ActionChip, '还有 1 张图片，点击展开');
      expect(
        find.ancestor(of: chip, matching: find.byType(Center)),
        findsWidgets,
      );

      await tester.tap(chip);
      await tester.pump();
      expect(find.text('还有 1 张图片，点击展开'), findsNothing);
    });

    testWidgets('refreshes link color when theme seed changes', (tester) async {
      Color? linkColor() {
        Color? walk(InlineSpan span) {
          if (span is TextSpan) {
            if (span.text?.contains('themed link') == true &&
                span.style?.color != null) {
              return span.style!.color;
            }
            for (final child in span.children ?? const <InlineSpan>[]) {
              final found = walk(child);
              if (found != null) return found;
            }
          }
          return null;
        }

        for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
          final found = walk(rich.text);
          if (found != null) return found;
        }
        return null;
      }

      await tester.pumpWidget(
        const _ThemeSwitchBbcodeHost(),
      );
      await tester.pump();

      final purpleLink = linkColor();
      final purplePrimary = Theme.of(
        tester.element(find.byType(BbcodeRenderer)),
      ).colorScheme.primary;
      expect(purpleLink, isNotNull);

      await tester.tap(find.text('switch theme'));
      await tester.pump();

      final bluePrimary = Theme.of(
        tester.element(find.byType(BbcodeRenderer)),
      ).colorScheme.primary;
      expect(bluePrimary, isNot(equals(purplePrimary)));

      final blueLink = linkColor();
      expect(blueLink, isNotNull);
      expect(blueLink, equals(bluePrimary));
    });

    testWidgets('opens forum links with the App router', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: BbcodeRenderer(
                bbcode:
                    '[url=https://bbs.stage1st.com/2b/forum.php?mod=viewthread&tid=123&page=2]论坛链接[/url]',
                imageIndexCounter: PostImageIndexCounter(),
              ),
            ),
          ),
          GoRoute(
            path: '/thread/:tid',
            builder: (context, state) => Scaffold(
              body: Text('主题 ${state.pathParameters['tid']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => SettingsNotifier()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme('purple'),
            routerConfig: router,
          ),
        ),
      );

      await tester.tapOnText(find.textRange.ofSubstring('论坛链接'));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), '/thread/123?page=2');
      expect(find.text('主题 123'), findsOneWidget);
    });
  });
}

class _ThemeSwitchBbcodeHost extends StatefulWidget {
  const _ThemeSwitchBbcodeHost();

  @override
  State<_ThemeSwitchBbcodeHost> createState() => _ThemeSwitchBbcodeHostState();
}

class _ThemeSwitchBbcodeHostState extends State<_ThemeSwitchBbcodeHost> {
  String _seed = 'purple';

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: AppSettings(themeColor: _seed),
          ),
        ),
      ],
      child: MaterialApp(
        key: ValueKey(_seed),
        theme: AppTheme.lightTheme(_seed),
        home: Scaffold(
          body: Column(
            children: [
              BbcodeRenderer(
                bbcode: '[url=https://example.com]themed link[/url]',
                imageIndexCounter: PostImageIndexCounter(),
              ),
              FilledButton(
                onPressed: () => setState(() => _seed = 'blue'),
                child: const Text('switch theme'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
