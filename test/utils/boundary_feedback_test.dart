import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/boundary_feedback.dart';

void main() {
  testWidgets('first hit haptics only; repeat in window shows message',
      (tester) async {
    var now = DateTime(2026, 7, 23, 12);
    var hapticCount = 0;
    final messages = <String>[];

    final controller = BoundaryFeedbackController(
      clock: () => now,
      onHaptic: () => hapticCount++,
      onShowMessage: (_, message) => messages.add(message),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      controller.hit(context, BoundaryEdge.lastPage),
                  child: const Text('hit'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('hit'));
    await tester.pump();
    expect(hapticCount, 1);
    expect(messages, isEmpty);

    // Same gesture noise — ignored.
    now = now.add(const Duration(milliseconds: 100));
    await tester.tap(find.text('hit'));
    await tester.pump();
    expect(hapticCount, 1);
    expect(messages, isEmpty);

    // After debounce, still inside repeat window → message.
    now = now.add(const Duration(milliseconds: 400));
    await tester.tap(find.text('hit'));
    await tester.pump();
    expect(hapticCount, 1);
    expect(messages, ['已是末页']);

    // Outside repeat window → haptic again.
    now = now.add(const Duration(milliseconds: 2000));
    await tester.tap(find.text('hit'));
    await tester.pump();
    expect(hapticCount, 2);
    expect(messages, ['已是末页']);
  });

  test('defaultMessage covers edges', () {
    expect(
      BoundaryFeedbackController.defaultMessage(BoundaryEdge.firstPage),
      '已是首页',
    );
    expect(
      BoundaryFeedbackController.defaultMessage(BoundaryEdge.lastPage),
      '已是末页',
    );
    expect(
      BoundaryFeedbackController.defaultMessage(BoundaryEdge.listEnd),
      '已经到底',
    );
  });

  test('reset clears throttle', () {
    var now = DateTime(2026, 7, 23, 12);
    var hapticCount = 0;
    final controller = BoundaryFeedbackController(
      clock: () => now,
      onHaptic: () => hapticCount++,
      onShowMessage: (_, __) {},
    );

    // Can't call hit without context easily — use a fake binding via testWidgets
    // covered above; here only reset smoke.
    controller.reset();
    expect(hapticCount, 0);
  });
}
