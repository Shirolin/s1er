import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/forum_split_breadcrumb_title.dart';
import 'package:s1er/widgets/pagination_bar.dart';
import 'package:s1er/widgets/s1_fab_layout.dart';
import 'package:s1er/widgets/s1_reading_column.dart';
import 'package:s1er/utils/window_size.dart';

void main() {
  testWidgets('ForumSplitBreadcrumbTitle renders forum and thread segments',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          appBar: AppBar(
            title: ForumSplitBreadcrumbTitle(
              forumLabel: '游戏论坛',
              threadTitle: '测试主题',
              onForumTap: () {},
              onThreadTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('游戏论坛'), findsOneWidget);
    expect(find.text('›'), findsOneWidget);
    expect(find.text('测试主题'), findsOneWidget);
  });

  testWidgets('S1FabStack renders extended FAB when configured',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1FabStack(
            primary: S1FabItem(
              heroTag: 'newThread',
              icon: Icons.add,
              tooltip: '发新主题',
              label: '发新主题',
              extended: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('发新主题'), findsOneWidget);
  });

  testWidgets('PaginationBar shows thread list context label in split mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PaginationBar(
            currentPage: 2,
            totalPages: 10,
            contextLabel: '主题',
            contextTooltip: '主题列表分页',
            onPageChanged: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('主题'), findsOneWidget);
    expect(find.textContaining('第 2 / 10 页'), findsOneWidget);
  });

  testWidgets('embedded PaginationBar uses reply page label and card surface',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ReadingColumn(
            showPaneGutter: true,
            child: PaginationBar(
              currentPage: 19,
              totalPages: 19,
              contextLabel: '回复页',
              contextTooltip: '帖子内回复分页，非主题列表',
              useCardSurface: true,
              alignToReadingColumn: true,
              respectReadingColumnWidth: true,
              onPageChanged: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('回复页'), findsOneWidget);
    final barWidth = tester.getSize(find.byType(PaginationBar)).width;
    expect(barWidth, S1Breakpoints.contentWidthReading);
    final scheme = AppTheme.lightTheme('purple').colorScheme;
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(PaginationBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(decorated.decoration, isA<BoxDecoration>());
    expect(
      (decorated.decoration as BoxDecoration).color,
      S1Surface.card(scheme),
    );
  });
}
