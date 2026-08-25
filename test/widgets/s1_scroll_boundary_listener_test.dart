import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/boundary_feedback.dart';
import 'package:s1er/widgets/s1_scroll_boundary_listener.dart';

void main() {
  Future<void> dispatchEndOverscroll(WidgetTester tester) async {
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    OverscrollNotification(
      metrics: scrollable.position,
      overscroll: 24,
      context: scrollable.context,
    ).dispatch(scrollable.context);
    await tester.pump();
  }

  testWidgets(
    'repeat terminal overscroll triggers onRefresh once per gesture',
    (tester) async {
      var now = DateTime(2026, 7, 23, 12);
      var refreshCount = 0;
      final messages = <String>[];
      final feedback = BoundaryFeedbackController(
        clock: () => now,
        onHaptic: () {},
        onShowMessage: (_, message) => messages.add(message),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: S1ScrollBoundaryListener(
              isTerminal: true,
              feedback: feedback,
              onRefresh: () async {
                refreshCount++;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 48, child: Text('short'))],
              ),
            ),
          ),
        ),
      );

      await dispatchEndOverscroll(tester);
      expect(refreshCount, 0);
      expect(messages, isEmpty);

      now = now.add(const Duration(milliseconds: 500));
      await dispatchEndOverscroll(tester);
      expect(refreshCount, 1);
      expect(messages, isEmpty);

      now = now.add(const Duration(milliseconds: 500));
      await dispatchEndOverscroll(tester);
      expect(refreshCount, 1);
    },
  );

  testWidgets('non-terminal overscroll does not refresh', (tester) async {
    var now = DateTime(2026, 7, 23, 12);
    var refreshCount = 0;
    final feedback = BoundaryFeedbackController(
      clock: () => now,
      onHaptic: () {},
      onShowMessage: (_, __) {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ScrollBoundaryListener(
            isTerminal: false,
            feedback: feedback,
            onRefresh: () async {
              refreshCount++;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 48, child: Text('mid page'))],
            ),
          ),
        ),
      ),
    );

    await dispatchEndOverscroll(tester);
    now = now.add(const Duration(milliseconds: 500));
    await dispatchEndOverscroll(tester);
    expect(refreshCount, 0);
  });
}
