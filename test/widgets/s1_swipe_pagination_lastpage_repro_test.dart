import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:s1er/theme/app_theme.dart";
import "package:s1er/widgets/s1_fab_layout.dart";
import "package:s1er/widgets/s1_swipe_pagination.dart";

void main() {
  Future<void> flingPrev(WidgetTester tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(find.byType(PageView), Offset(size.width, 0), 2500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets("external last jump while swipe paging in flight",
      (tester) async {
    var currentPage = 3;
    const total = 5;
    final gate = Completer<void>();
    final requested = <int>[];

    Widget build() => MaterialApp(
          theme: AppTheme.lightTheme("purple"),
          home: Scaffold(
            body: S1SwipePagination(
              currentPage: currentPage,
              totalPages: total,
              onPageChanged: (page) async {
                requested.add(page);
                // Simulate slow network; parent may jump elsewhere meanwhile
                await gate.future;
                currentPage = page;
              },
              pageBuilder: (c, sc) => ListView(
                controller: sc,
                children: [
                  SizedBox(height: 800, child: Text("Page $currentPage")),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();

    // Start swipe to page 4 (next)
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(find.byType(PageView), Offset(-size.width, 0), 2500);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // External jump to last while _isPaging/_pendingPage=4
    currentPage = total;
    await tester.pumpWidget(build());
    await tester.pump();

    // Complete the in-flight swipe request
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Parent would set currentPage from swipe callback to 4
    currentPage = 4;
    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 100));

    final pc = tester.widget<PageView>(find.byType(PageView)).controller!;
    debugPrint(
      "after race page=${pc.page} requested=$requested current=$currentPage",
    );
    debugPrint(
      "physics paging bar visible=${find.byType(LinearProgressIndicator).evaluate().isNotEmpty}",
    );

    // User now on page 4 somehow; jump display to last as user expects
    currentPage = total;
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await flingPrev(tester);
    debugPrint("after flingPrev page=${pc.page} requested=$requested");
    expect(requested, contains(total - 1));
  });

  testWidgets("metrics zero after external page change", (tester) async {
    var currentPage = 1;
    S1ScrollMetrics? last;
    var showDown = false;

    Widget build() => MaterialApp(
          theme: AppTheme.lightTheme("purple"),
          home: Scaffold(
            body: S1SwipePagination(
              currentPage: currentPage,
              totalPages: 5,
              onScrollMetricsChanged: (m) {
                last = m;
                showDown = S1FabLayout.shouldShowScrollDown(
                  metrics: m,
                  currentlyShowing: showDown,
                );
              },
              onPageChanged: (_) async {},
              pageBuilder: (c, sc) => ListView(
                controller: sc,
                children: const [SizedBox(height: 2000, child: Text("X"))],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(last!.maxScrollExtent, greaterThan(0));
    expect(showDown, isTrue);

    currentPage = 5;
    await tester.pumpWidget(build());
    // right after didUpdateWidget replace, before/at post-frame
    await tester.pump();
    debugPrint("after external jump metrics=$last showDown=$showDown");
    // One more frame for list layout
    await tester.pump();
    debugPrint("after second frame metrics=$last showDown=$showDown");
  });
}
