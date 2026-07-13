import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/scroll_floor.dart';

import '../helpers/test_theme.dart';

Widget buildScrollHarness({
  required List<GlobalKey> postKeys,
  required ScrollController controller,
  required double postHeight,
  double viewportHeight = 400,
}) {
  return wrapWithAppTheme(
    SizedBox(
      height: viewportHeight,
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          children: [
            for (var i = 0; i < postKeys.length; i++)
              SizedBox(
                key: postKeys[i],
                height: postHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('Post ${i + 1}'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('ScrollFloorNavigator advances anchor when next post is visible',
      (tester) async {
    final postKeys = List.generate(4, (_) => GlobalKey());
    final controller = ScrollController();

    await tester.pumpWidget(
      buildScrollHarness(
        postKeys: postKeys,
        controller: controller,
        postHeight: 120,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(controller.position.maxScrollExtent, greaterThan(0));

    unawaited(
      ScrollFloorNavigator.scrollToNextFloor(
        postKeys: postKeys,
        onAtLastFloor: () => fail('should not reach last floor'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));

    final post2Box = tester.renderObject<RenderBox>(find.text('Post 2'));
    final viewportTop = tester
        .renderObject<RenderBox>(find.byType(SingleChildScrollView))
        .localToGlobal(Offset.zero)
        .dy;
    final post2Top = post2Box.localToGlobal(Offset.zero).dy;
    final viewportHeight = tester
        .renderObject<RenderBox>(find.byType(SingleChildScrollView))
        .size
        .height;
    final expectedTop =
        viewportTop + viewportHeight * ScrollFloorNavigator.revealAlignment;

    expect(post2Top, closeTo(expectedTop, 12));
  });

  testWidgets('ScrollFloorNavigator uses reading anchor not first post only',
      (tester) async {
    final postKeys = List.generate(3, (_) => GlobalKey());
    final controller = ScrollController();

    await tester.pumpWidget(
      buildScrollHarness(
        postKeys: postKeys,
        controller: controller,
        postHeight: 200,
      ),
    );
    await tester.pumpAndSettle();

    // Post 2 已在阅读锚线附近。
    controller.jumpTo(168);
    await tester.pumpAndSettle();
    expect(controller.offset, 168);

    unawaited(
      ScrollFloorNavigator.scrollToNextFloor(
        postKeys: postKeys,
        onAtLastFloor: () => fail('should scroll to post 3'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(168));
    // 内容不足时滚到 maxScrollExtent，仍应比当前位置更靠下。
    expect(controller.offset, lessThanOrEqualTo(controller.position.maxScrollExtent));
  });
}
