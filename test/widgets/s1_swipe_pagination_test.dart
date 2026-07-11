import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
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

  Widget buildHarness({
    required int currentPage,
    required int totalPages,
    required Future<void> Function(int page) onPageChanged,
    bool enabled = true,
    Key? key,
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
          pageBuilder: (context, scrollController) => ListView(
            controller: scrollController,
            children: [
              SizedBox(
                height: 800,
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
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(controller.offset, 0);
  });
}
