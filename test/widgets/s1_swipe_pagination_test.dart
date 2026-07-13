import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';
import 'package:s1_app/widgets/s1_swipe_pagination.dart';

void main() {
  Future<void> swipeToNextPage(WidgetTester tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(
      find.byType(PageView),
      Offset(-size.width, 0),
      2500,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> swipeToPreviousPage(WidgetTester tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(
      find.byType(PageView),
      Offset(size.width, 0),
      2500,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Widget buildHarness({
    required int currentPage,
    required int totalPages,
    required Future<void> Function(int page) onPageChanged,
    bool enabled = true,
    Key? key,
    ValueChanged<S1ScrollMetrics>? onScrollMetricsChanged,
    double contentHeight = 800,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme('purple'),
      home: Scaffold(
        body: S1SwipePagination(
          key: key,
          currentPage: currentPage,
          totalPages: totalPages,
          enabled: enabled,
          onPageChanged: onPageChanged,
          onScrollMetricsChanged: onScrollMetricsChanged,
          pageBuilder: (context, scrollController) => ListView(
            controller: scrollController,
            children: [
              SizedBox(
                height: contentHeight,
                child: Center(child: Text('Page $currentPage')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('S1SwipePagination hides PageView when only one page', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        currentPage: 1,
        totalPages: 1,
        onPageChanged: (_) async {},
      ),
    );

    expect(find.byType(PageView), findsNothing);
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('S1SwipePagination shows PageView for multiple pages', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        currentPage: 2,
        totalPages: 5,
        onPageChanged: (_) async {},
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
  });

  testWidgets('S1SwipePagination right swipe requests previous page', (tester) async {
    int? requestedPage;

    await tester.pumpWidget(
      buildHarness(
        currentPage: 3,
        totalPages: 5,
        onPageChanged: (page) async {
          requestedPage = page;
        },
      ),
    );
    await tester.pump();

    await swipeToPreviousPage(tester);

    expect(requestedPage, 2);
  });

  testWidgets('S1SwipePagination drag right requests previous page with nested ListView', (tester) async {
    int? requestedPage;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1SwipePagination(
            currentPage: 3,
            totalPages: 5,
            onPageChanged: (page) async {
              requestedPage = page;
            },
            pageBuilder: (context, scrollController) => RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                controller: scrollController,
                itemCount: 30,
                itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Scroll list down first (common real-world state)
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(
      find.byType(PageView),
      Offset(size.width, 0),
      2500,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(requestedPage, 2);
  });

  testWidgets('S1SwipePagination left swipe requests next page', (tester) async {
    int? requestedPage;

    await tester.pumpWidget(
      buildHarness(
        currentPage: 2,
        totalPages: 5,
        onPageChanged: (page) async {
          requestedPage = page;
        },
      ),
    );
    await tester.pump();

    await swipeToNextPage(tester);

    expect(requestedPage, 3);
  });

  testWidgets('S1SwipePagination right swipe on first page does not request page', (tester) async {
    var requestCount = 0;

    await tester.pumpWidget(
      buildHarness(
        currentPage: 1,
        totalPages: 5,
        onPageChanged: (_) async {
          requestCount++;
        },
      ),
    );
    await tester.pump();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(
      find.byType(PageView),
      Offset(size.width, 0),
      2500,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(requestCount, 0);
  });

  testWidgets('S1SwipePagination left swipe on last page does not request page', (tester) async {
    var requestCount = 0;

    await tester.pumpWidget(
      buildHarness(
        currentPage: 5,
        totalPages: 5,
        onPageChanged: (_) async {
          requestCount++;
        },
      ),
    );
    await tester.pump();

    await swipeToNextPage(tester);

    expect(requestCount, 0);
  });

  testWidgets('S1SwipePagination shows loading bar while paging', (tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      buildHarness(
        currentPage: 2,
        totalPages: 5,
        onPageChanged: (_) => completer.future,
      ),
    );
    await tester.pump();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.fling(
      find.byType(PageView),
      Offset(-size.width, 0),
      2500,
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pump();
  });

  testWidgets('S1SwipePagination resets scroll when currentPage changes externally',
      (tester) async {
    final key = GlobalKey<S1SwipePaginationState>();
    var currentPage = 1;

    Widget build() {
      return MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: S1SwipePagination(
                  key: key,
                  currentPage: currentPage,
                  totalPages: 5,
                  onPageChanged: (_) async {},
                  pageBuilder: (context, scrollController) => ListView.builder(
                    controller: scrollController,
                    itemCount: 30,
                    itemBuilder: (context, index) => SizedBox(
                      height: 50,
                      child: Text('P$currentPage-$index'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(400);
    await tester.pump();

    currentPage = 2;
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(
      tester.widget<ListView>(find.byType(ListView)).controller!.offset,
      0,
    );
  });

  testWidgets('S1SwipePagination exposes scrollToTop', (tester) async {
    final key = GlobalKey<S1SwipePaginationState>();

    await tester.pumpWidget(
      buildHarness(
        key: key,
        currentPage: 2,
        totalPages: 5,
        onPageChanged: (_) async {},
      ),
    );
    await tester.pump();

    final state = key.currentState!;
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(500);
    await tester.pump();

    unawaited(state.scrollToTop());
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
  });

  testWidgets('S1SwipePagination exposes scrollToBottom', (tester) async {
    final key = GlobalKey<S1SwipePaginationState>();

    await tester.pumpWidget(
      buildHarness(
        key: key,
        currentPage: 2,
        totalPages: 5,
        onPageChanged: (_) async {},
      ),
    );
    await tester.pump();

    final state = key.currentState!;
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    expect(controller.offset, 0);

    unawaited(state.scrollToBottom());
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('S1SwipePagination reports maxScrollExtent in metrics',
      (tester) async {
    S1ScrollMetrics? lastMetrics;

    await tester.pumpWidget(
      buildHarness(
        currentPage: 1,
        totalPages: 1,
        contentHeight: 2000,
        onPageChanged: (_) async {},
        onScrollMetricsChanged: (m) => lastMetrics = m,
      ),
    );
    await tester.pumpAndSettle();

    expect(lastMetrics, isNotNull);
    expect(lastMetrics!.maxScrollExtent, greaterThan(0));

    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(200);
    await tester.pump();

    expect(lastMetrics!.offset, 200);
    expect(lastMetrics!.maxScrollExtent, controller.position.maxScrollExtent);
  });
}
