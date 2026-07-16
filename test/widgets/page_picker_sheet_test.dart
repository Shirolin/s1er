import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/page_picker_sheet.dart';

void main() {
  testWidgets('showPagePickerSheet lists pages without current highlight',
      (tester) async {
    int? selectedPage;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPagePickerSheet(
                context: context,
                totalPages: 5,
                subtitle: '测试帖子',
                pageItemLabelBuilder: (page) => '第 $page 页',
                onPageSelected: (page) => selectedPage = page,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('选择页码'), findsOneWidget);
    expect(find.text('测试帖子'), findsOneWidget);
    expect(find.text('跳转'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(selectedPage, 3);
  });

  testWidgets('desktop page picker uses a compact two-column grid',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPagePickerSheet(
                context: context,
                totalPages: 4,
                currentPage: 1,
                subtitle: '测试帖子',
                pageItemLabelBuilder: (page) {
                  final start = (page - 1) * 40 + 1;
                  return '第 $start - ${page * 40} 楼';
                },
                onPageSelected: (_) {},
              ),
              child: const Text('打开桌面页码'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开桌面页码'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('第 1 - 40 楼'), findsOneWidget);
    expect(find.text('第 121 - 160 楼'), findsOneWidget);
    expect(tester.getSize(find.byType(PagePickerSheet)).height, lessThan(500));
  });

  testWidgets(
      'desktop thread list keeps first pages, last page and direct jump',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPagePickerSheet(
                context: context,
                totalPages: 4076,
                onPageSelected: (_) {},
              ),
              child: const Text('打开大量页码'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开大量页码'));
    await tester.pumpAndSettle();

    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('第 3 页'), findsOneWidget);
    expect(find.text('第 4076 页'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('跳转'), findsOneWidget);
  });
}
