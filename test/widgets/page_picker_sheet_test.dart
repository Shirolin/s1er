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
}
