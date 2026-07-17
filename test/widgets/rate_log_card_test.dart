import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/rate_log.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/post_item.dart';
import 'package:s1er/widgets/rate_log_card.dart';

class _SeededRateLogsNotifier extends ThreadRateLogsNotifier {
  _SeededRateLogsNotifier(super.tid, this.seed);

  final Map<String, PostRateLog> seed;

  @override
  Map<String, PostRateLog> build() => seed;
}

void main() {
  Widget wrap(
    Widget child, {
    required String tid,
    required Map<String, PostRateLog> seed,
  }) {
    return ProviderScope(
      overrides: [
        threadRateLogsProvider(tid).overrideWith(
          () => _SeededRateLogsNotifier(tid, seed),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(body: child),
      ),
    );
  }

  group('RateLogCard', () {
    testWidgets('shows summary with positive score', (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [RateLog(username: 'a', score: 2)],
        totalScore: 6,
        participantCount: 4,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('评分 +6'), findsOneWidget);
      expect(find.text('(4人)'), findsOneWidget);
    });

    testWidgets('shows summary with negative score', (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [RateLog(username: 'a', score: -3)],
        totalScore: -3,
        participantCount: 1,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('评分 -3'), findsOneWidget);
      expect(find.text('(1人)'), findsOneWidget);
    });

    testWidgets('PostItem shows rate log when commentcount is zero',
        (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [RateLog(username: 'a', score: 2)],
        totalScore: 2,
        participantCount: 1,
      );

      await tester.pumpWidget(
        wrap(
          PostItem(
            post: Post(
              pid: '1',
              message: 'body',
              author: 'author',
              authorId: '1',
              dateline: 0,
              floor: 1,
            ),
            tid: '123',
          ),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('评分 +2'), findsOneWidget);
    });

    testWidgets('expands to show entries on tap', (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(username: 'rustincohle', score: 2, reason: '好评加鹅'),
          RateLog(username: 'another', score: -1, reason: '扣分'),
        ],
        totalScore: 1,
        participantCount: 2,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('rustincohle'), findsOneWidget);

      await tester.tap(find.byType(RateLogCard));
      await tester.pumpAndSettle();

      expect(find.text('rustincohle'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('好评加鹅'), findsOneWidget);
      expect(find.text('another'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('扣分'), findsOneWidget);
    });

    testWidgets('shows first three entries while collapsed', (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(username: 'user1', score: 1),
          RateLog(username: 'user2', score: 1),
          RateLog(username: 'user3', score: 1),
          RateLog(username: 'user4', score: 1),
        ],
        totalScore: 4,
        participantCount: 4,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('user1'), findsOneWidget);
      expect(find.text('user2'), findsOneWidget);
      expect(find.text('user3'), findsOneWidget);
      expect(find.text('user4'), findsNothing);
      expect(find.text('查看其余1条'), findsOneWidget);
    });

    testWidgets('shows server-truncated hidden count while collapsed',
        (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(username: 'user1', score: 1),
          RateLog(username: 'user2', score: 1),
          RateLog(username: 'user3', score: 1),
        ],
        totalScore: 17,
        participantCount: 13,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('查看其余10条'), findsOneWidget);

      await tester.tap(find.text('查看其余10条'));
      await tester.pumpAndSettle();

      expect(find.text('收起'), findsOneWidget);
      expect(find.text('加载完整评分历史 (共13人)'), findsOneWidget);
    });

    testWidgets('expands to show all collapsed preview entries',
        (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(username: 'user1', score: 1),
          RateLog(username: 'user2', score: 1),
          RateLog(username: 'user3', score: 1),
          RateLog(username: 'user4', score: 1),
        ],
        totalScore: 4,
        participantCount: 4,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(RateLogCard));
      await tester.pumpAndSettle();

      expect(find.text('user4'), findsOneWidget);
    });

    testWidgets('shows rated timestamp when available', (tester) async {
      final rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(
            username: 'user',
            score: 1,
            ratedAt: DateTime(2018, 4, 14, 22, 20),
          ),
        ],
        totalScore: 1,
        participantCount: 1,
      );

      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2018-04-14 22:20'), findsOneWidget);
    });
  });
}
