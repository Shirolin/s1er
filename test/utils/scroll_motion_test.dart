import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/scroll_motion.dart';

void main() {
  test('durationForDelta scales with distance and caps', () {
    final short = S1ScrollMotion.durationForDelta(80, 600);
    final long = S1ScrollMotion.durationForDelta(1800, 600);
    final capped = S1ScrollMotion.durationForDelta(6000, 600, toBottom: true);

    expect(short.inMilliseconds, greaterThanOrEqualTo(220));
    expect(long.inMilliseconds, greaterThan(short.inMilliseconds));
    expect(capped.inMilliseconds, lessThanOrEqualTo(560));
  });

  testWidgets('animateToMaxExtent reaches lazy list bottom', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: ListView.builder(
              controller: controller,
              itemCount: 30,
              itemBuilder: (context, index) => SizedBox(
                height: 120,
                child: Text('Item $index'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 测试环境需 pump 帧驱动 ScrollPosition 动画。
    // ignore: unawaited_futures
    final future = S1ScrollMotion.animateToMaxExtent(controller.position);
    await tester.pumpAndSettle();
    await future;

    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );
  });
}
