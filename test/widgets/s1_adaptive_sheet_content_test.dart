import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/s1_adaptive_sheet.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('desktop uses ListTile action rows', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithAppTheme(
        const S1AdaptiveSheetScaffold(
          title: '测试标题',
          subtitle: '副标题',
          children: [
            S1AdaptiveActionTile(
              icon: Icons.push_pin,
              label: '钉在首页',
              onTap: _noop,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('钉在首页'), findsOneWidget);
    expect(find.text('副标题'), findsOneWidget);
  });

  testWidgets('compact uses mobile icon tile rows', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithAppTheme(
        const S1AdaptiveSheetScaffold(
          title: '测试标题',
          children: [
            S1AdaptiveActionTile(
              icon: Icons.push_pin,
              label: '钉在首页',
              onTap: _noop,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('钉在首页'), findsOneWidget);
  });

  testWidgets('header trailing renders beside title', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithAppTheme(
        const S1AdaptiveSheetScaffold(
          title: '选择页码',
          headerTrailing: Text('共 3 页'),
          children: [SizedBox()],
        ),
      ),
    );

    expect(find.text('选择页码'), findsOneWidget);
    expect(find.text('共 3 页'), findsOneWidget);
  });

  testWidgets('footer aligns primary action on desktop', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = false;
    await tester.pumpWidget(
      wrapWithAppTheme(
        S1AdaptiveSheetScaffold(
          title: '表单',
          footer: S1AdaptiveSheetFooter(
            primaryLabel: '提交',
            onPrimary: () => tapped = true,
            secondaryLabel: '取消',
            onSecondary: () {},
          ),
          children: const [SizedBox()],
        ),
      ),
    );

    await tester.tap(find.text('提交'));
    expect(tapped, isTrue);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });
}

void _noop() {}
