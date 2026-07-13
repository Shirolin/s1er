import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';
import 'package:s1_app/widgets/s1_swipe_pagination.dart';

void main() {
  Future<double> topOffset(WidgetTester tester, Finder finder) async {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero).dy;
  }

  Widget buildThreadDetailLikeHarness({
    required int totalPages,
    required int currentPage,
    ValueChanged<ScrollController>? onControllerCreated,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme('purple'),
      home: Scaffold(
        appBar: AppBar(title: const Text('Thread')),
        body: Column(
          children: [
            Expanded(
              child: S1ContentFabOverlay(
                fab: S1FabStack(
                  primary: S1FabItem(
                    heroTag: 'reply',
                    icon: Icons.edit,
                    tooltip: 'reply',
                    onPressed: () {},
                  ),
                ),
                child: S1SwipePagination(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: (_) async {},
                  pageBuilder: (context, scrollController) {
                    onControllerCreated?.call(scrollController);
                    return Scrollbar(
                      controller: scrollController,
                      child: ListView.builder(
                        controller: scrollController,
                        padding: S1FabLayout.threadDetailScrollBottomPadding,
                        itemCount: 3,
                        itemBuilder: (context, index) => _ShortPostCard(
                          label: 'Post ${index + 1}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  testWidgets('short posts on single-page thread start below app bar', (tester) async {
    await tester.pumpWidget(buildThreadDetailLikeHarness(
      totalPages: 1,
      currentPage: 1,
    ),);
    await tester.pumpAndSettle();

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final firstPostTop = await topOffset(tester, find.text('Post 1'));
    final viewportHeight = tester.getSize(find.byType(Scaffold)).height;

    expect(firstPostTop, greaterThan(appBarBottom - 1));
    expect(firstPostTop, lessThan(appBarBottom + 40));
    expect(firstPostTop, lessThan(viewportHeight * 0.35));
  });

  testWidgets('short posts on multi-page thread page 1 start below app bar', (tester) async {
    await tester.pumpWidget(buildThreadDetailLikeHarness(
      totalPages: 5,
      currentPage: 1,
    ),);
    await tester.pumpAndSettle();

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final firstPostTop = await topOffset(tester, find.text('Post 1'));

    expect(firstPostTop, greaterThan(appBarBottom - 1));
    expect(firstPostTop, lessThan(appBarBottom + 40));
  });

  testWidgets('stale scroll offset does not pin short posts to bottom', (tester) async {
    ScrollController? controller;

    await tester.pumpWidget(buildThreadDetailLikeHarness(
      totalPages: 1,
      currentPage: 1,
      onControllerCreated: (c) => controller = c,
    ),);
    await tester.pumpAndSettle();

    controller!.jumpTo(400);
    await tester.pump();

    expect(controller!.offset, 400);

    await tester.pumpWidget(buildThreadDetailLikeHarness(
      totalPages: 1,
      currentPage: 1,
    ),);
    await tester.pumpAndSettle();

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final resetTop = await topOffset(tester, find.text('Post 1'));
    expect(resetTop, greaterThan(appBarBottom - 1));
    expect(resetTop, lessThan(appBarBottom + 40));
  });
}

class _ShortPostCard extends StatelessWidget {
  const _ShortPostCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 80,
        child: Center(child: Text(label)),
      ),
    );
  }
}
