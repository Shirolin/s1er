import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/rate_log.dart';
import 'package:s1_app/widgets/rate_log_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
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

      await tester.pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
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

      await tester.pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
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

      await tester.pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
      await tester.pumpAndSettle();

      expect(find.text('rustincohle'), findsNothing);

      await tester.tap(find.byType(RateLogCard));
      await tester.pumpAndSettle();

      expect(find.text('rustincohle'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('好评加鹅'), findsOneWidget);
      expect(find.text('another'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('扣分'), findsOneWidget);
    });

    testWidgets('collapses when tapped again', (tester) async {
      const rateLog = PostRateLog(
        pid: '1',
        entries: [RateLog(username: 'user', score: 1)],
        totalScore: 1,
        participantCount: 1,
      );

      await tester.pumpWidget(wrap(const RateLogCard(rateLog: rateLog, tid: '123')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(RateLogCard));
      await tester.pumpAndSettle();
      expect(find.text('user'), findsOneWidget);

      await tester.tap(find.byType(RateLogCard));
      await tester.pumpAndSettle();
      expect(find.text('user'), findsNothing);
    });
  });
}
