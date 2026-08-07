import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/attendance_result.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/daily_sign_card.dart';

void main() {
  testWidgets('DailySignCard shows sign button and invokes callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: DailySignCard(
            isSubmitting: false,
            result: null,
            onSign: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('每日签到'), findsOneWidget);
    await tester.tap(find.text('签到'));
    expect(tapped, isTrue);
  });

  testWidgets('DailySignCard shows completed state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: DailySignCard(
            isSubmitting: false,
            result: const AttendanceResult(
              outcome: AttendanceOutcome.alreadySigned,
              message: '抱歉，您今日已签到',
            ),
            onSign: () {},
          ),
        ),
      ),
    );

    expect(find.text('今日已签到'), findsOneWidget);
    expect(find.text('抱歉，您今日已签到'), findsOneWidget);
    expect(find.text('签到'), findsNothing);

    // 已签到态：右侧内边距回到 16，与左侧对齐（裸 icon 不享受按钮的内边距）。
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.fromLTRB(16, 14, 16, 14),
      ),
      findsOneWidget,
    );
  });

  testWidgets('DailySignCard button state keeps reduced right padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: DailySignCard(
            isSubmitting: false,
            result: null,
            onSign: () {},
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.fromLTRB(16, 14, 12, 14),
      ),
      findsOneWidget,
    );
  });
}
