import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/post_image_index_counter.dart';
import 'package:s1_app/utils/quote_jump.dart';
import 'package:s1_app/widgets/bbcode_renderer.dart';
import 'package:s1_app/widgets/quote_block.dart';

void main() {
  group('QuoteJumpParser', () {
    test('parses HTML findpost with ptid and pid', () {
      const html =
          '<a href="forum.php?mod=redirect&amp;goto=findpost&amp;pid=12&amp;ptid=99">'
          'author</a> 发表于 2024-01-01 12:00';
      final link = QuoteJumpParser.extractLink(html)!;
      final parsed = QuoteJumpParser.parsePostLink(link);
      expect(parsed?.tid, '99');
      expect(parsed?.pid, '12');
    });

    test('parses BBCode url findpost', () {
      const bbc =
          '[url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]bob[/url]';
      final link = QuoteJumpParser.extractLink(bbc)!;
      final parsed = QuoteJumpParser.parsePostLink(link);
      expect(parsed?.tid, '2');
      expect(parsed?.pid, '1');
    });

    test('falls back to currentTid when ptid missing', () {
      final parsed = QuoteJumpParser.parsePostLink(
        'forum.php?mod=redirect&goto=findpost&pid=55',
        fallbackTid: '777',
      );
      expect(parsed?.tid, '777');
      expect(parsed?.pid, '55');
    });

    test('returns null without ptid or fallback', () {
      expect(
        QuoteJumpParser.parsePostLink(
          'forum.php?mod=redirect&goto=findpost&pid=55',
        ),
        isNull,
      );
    });
  });

  group('BbcodeQuoteSplitter', () {
    test('splits [post] like [quote]', () {
      final segs = BbcodeQuoteSplitter.split(
        'before [post]inner[/post] after [quote]q[/quote]',
      );
      expect(segs.where((s) => s.isQuote).length, 2);
      expect(segs.where((s) => s.isQuote).first.text, 'inner');
    });

    test('splits reply_wrap', () {
      final segs = BbcodeQuoteSplitter.split(
        '<div class="reply_wrap">body</div>tail',
      );
      expect(segs.where((s) => s.isQuote).single.text, 'body');
    });
  });

  group('QuoteBlock jump navigation', () {
    testWidgets('tapping header pushes thread with pid', (tester) async {
      String? pushed;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: QuoteBlock(
                content:
                    '<a href="forum.php?mod=redirect&amp;goto=findpost&amp;pid=42&amp;ptid=100">'
                    'alice 发表于 2024-01-01 12:00</a><br/>quote body',
                imageIndexCounter: PostImageIndexCounter(),
                currentTid: '100',
              ),
            ),
          ),
          GoRoute(
            path: '/thread/:tid',
            builder: (context, state) {
              pushed =
                  '/thread/${state.pathParameters['tid']}?pid=${state.uri.queryParameters['pid']}';
              return const Scaffold(body: Text('thread'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => SettingsNotifier(initial: const AppSettings()),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme('purple'),
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.open_in_new));
      await tester.pumpAndSettle();

      expect(pushed, '/thread/100?pid=42');
    });

    testWidgets('[post] segment renders QuoteBlock', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => SettingsNotifier(initial: const AppSettings()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: Scaffold(
              body: BbcodeRenderer(
                bbcode:
                    '[post]<a href="forum.php?mod=redirect&goto=findpost&pid=1&ptid=2">'
                    'x 发表于 2024-01-01 12:00</a>body[/post]',
                imageIndexCounter: PostImageIndexCounter(),
                currentTid: '2',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(QuoteBlock), findsOneWidget);
    });
  });
}
