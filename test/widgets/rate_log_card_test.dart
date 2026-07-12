import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/models/rate_log.dart';
import 'package:s1_app/widgets/rate_log_card.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
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

      await tester
          .pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
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

      await tester
          .pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
      await tester.pumpAndSettle();

      expect(find.text('评分 -3'), findsOneWidget);
      expect(find.text('(1人)'), findsOneWidget);
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

      await tester
          .pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
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

      await tester
          .pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
      await tester.pumpAndSettle();

      expect(find.text('user1'), findsOneWidget);
      expect(find.text('user2'), findsOneWidget);
      expect(find.text('user3'), findsOneWidget);
      expect(find.text('user4'), findsNothing);
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

      await tester
          .pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
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

      await tester.pumpWidget(wrap(RateLogCard(rateLog: rateLog, tid: '123')));
      await tester.pumpAndSettle();

      expect(find.text('2018-04-14 22:20'), findsOneWidget);
    });
  });
}
