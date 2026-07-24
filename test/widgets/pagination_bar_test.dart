import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/pagination_bar.dart';

void main() {
  testWidgets('PaginationBar hidden when only one page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 1,
            totalPages: 1,
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(PaginationBar), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('PaginationBar shows controls for multiple pages',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 2,
            totalPages: 5,
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('第 2 / 5 页'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('PaginationBar prev button triggers onPageChanged',
      (tester) async {
    int? requestedPage;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 3,
            totalPages: 5,
            onPageChanged: (page) async {
              requestedPage = page;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requestedPage, 2);
  });

  testWidgets('Page picker opens from indicator tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 2,
            totalPages: 5,
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('第 2 / 5 页'));
    await tester.pumpAndSettle();

    expect(find.text('选择页码'), findsOneWidget);
    expect(find.text('跳转'), findsOneWidget);
  });

  testWidgets('PaginationBar page indicator meets 48dp touch target',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 2,
            totalPages: 5,
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );

    final indicatorBox = tester.getSize(
      find.ancestor(
        of: find.text('第 2 / 5 页'),
        matching: find.byType(InkWell),
      ),
    );
    expect(
      indicatorBox.height,
      greaterThanOrEqualTo(S1BottomBarStyle.minTouchTarget),
    );
  });

  testWidgets('PaginationBar edge tooltips reflect first/last page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 1,
            totalPages: 5,
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );

    final prev = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(prev.tooltip, '已是首页');
    expect(prev.onPressed, isNull);

    final first = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.first_page),
    );
    expect(first.tooltip, '已是首页');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 5,
            totalPages: 5,
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.tooltip, '已是末页');
    expect(next.onPressed, isNull);
  });
}
