import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/rate_log.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/services/rate_log_service.dart';
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

    testWidgets('PostItem fetches only marked pids when built', (tester) async {
      clearRateLogSessionCacheForTest();
      final service = _RecordingRateLogService();
      final container = ProviderContainer(
        overrides: [rateLogServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(threadRateLogsProvider('123'), (_, __) {});
      addTearDown(sub.close);
      container
          .read(threadRateLogsProvider('123').notifier)
          .markPids(['1', '2']);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: Scaffold(
              body: PostItem(
                post: _post(pid: '1'),
                tid: '123',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(service.requestedPids, ['1']);
    });

    testWidgets('PostItem does not fetch unmarked pids', (tester) async {
      clearRateLogSessionCacheForTest();
      final service = _RecordingRateLogService();
      final container = ProviderContainer(
        overrides: [rateLogServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: Scaffold(
              body: PostItem(
                post: _post(pid: '1'),
                tid: '123',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(service.requestedPids, isEmpty);
    });

    testWidgets('PostItem cancels rate fetch when disposed before debounce',
        (tester) async {
      clearRateLogSessionCacheForTest();
      final service = _RecordingRateLogService();
      final container = ProviderContainer(
        overrides: [rateLogServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(threadRateLogsProvider('123'), (_, __) {});
      addTearDown(sub.close);
      container.read(threadRateLogsProvider('123').notifier).markPids(['1']);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: Scaffold(
              body: PostItem(
                post: _post(pid: '1'),
                tid: '123',
              ),
            ),
          ),
        ),
      );

      // 楼层在防抖窗口内被移出构建范围（快速划过/翻页）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 350));

      expect(service.requestedPids, isEmpty);
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

    testWidgets(
        'colors each entry score by its own sign regardless of totalScore',
        (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(username: 'plus_user', score: 2, reason: '加鹅'),
          RateLog(username: 'minus_user', score: -1, reason: '扣鹅'),
        ],
        totalScore: 1,
        participantCount: 2,
      );

      final theme = AppTheme.lightTheme('purple');
      await tester.pumpWidget(
        wrap(
          const RateLogCard(tid: '123', pid: '1'),
          tid: '123',
          seed: {'1': rateLog},
        ),
      );
      await tester.pumpAndSettle();

      final summaryScoreText = tester.widget<Text>(find.text('评分 +1'));
      final plusScoreText = tester.widget<Text>(find.text('+2'));
      final minusScoreText = tester.widget<Text>(find.text('-1'));

      expect(summaryScoreText.style?.color, theme.colorScheme.primary);
      expect(plusScoreText.style?.color, theme.colorScheme.primary);
      expect(minusScoreText.style?.color, theme.colorScheme.error);
    });

    testWidgets('renders long rating reason without single-line truncation',
        (tester) async {
      const longReason =
          '这是一段非常非常长的评分理由，用于验证评分卡不再将理由强制截断为单行省略号，而是能够完整自动换行展示全部内容。';
      const rateLog = PostRateLog(
        pid: '1',
        entries: [
          RateLog(username: 'user', score: 1, reason: longReason),
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

      final reasonText = tester.widget<Text>(find.text(longReason));
      expect(reasonText.maxLines, isNull);
      expect(reasonText.overflow, isNull);
    });
  });
}

Post _post({required String pid}) {
  return Post(
    pid: pid,
    message: 'body',
    author: 'author',
    authorId: '1',
    dateline: 0,
    floor: 1,
  );
}

class _RecordingRateLogService extends RateLogService {
  _RecordingRateLogService() : super(S1HttpClient.test(null, Dio()));

  final List<String> requestedPids = [];

  @override
  Future<PostRateLog?> fetchRateLog(String tid, String pid) async {
    requestedPids.add(pid);
    return null;
  }
}
