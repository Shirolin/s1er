import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
import 'package:s1er/widgets/share_card.dart';

import '../helpers/test_theme.dart';

Post _post() {
  return Post.fromJson({
    'pid': '1',
    'message': 'hello',
    'author': 'a',
    'authorid': '1',
    'dbdateline': '1720000000',
    'number': '1',
  });
}

void main() {
  testWidgets('ShareFloorBlock in-floor slice uses fixed viewport scroll', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    const viewportHeight = 400.0;

    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(
          MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: ShareFloorBlock(
              floor: ShareFloorData(post: _post(), displayFloor: 1),
              captureKey: GlobalKey(),
              inFloorSliceCapture: true,
              sliceScrollController: scrollController,
              sliceViewportLogicalHeight: viewportHeight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewport = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(RepaintBoundary),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(viewport.height, viewportHeight);

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.controller, scrollController);
    expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());
  });
}
