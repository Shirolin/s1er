import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/s1_adaptive_sheet.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('showS1ActionSheet uses Dialog on desktop', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithAppTheme(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showS1ActionSheet<void>(
              context: context,
              builder: (_) => const S1AdaptiveSheetScaffold(
                title: '操作',
                children: [
                  S1AdaptiveActionTile(
                    icon: Icons.push_pin,
                    label: '钉在首页',
                    onTap: _noop,
                  ),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('showS1ProfileSheet uses side sheet on large desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithAppTheme(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showS1ProfileSheet<void>(
              context: context,
              builder: (_) => const S1AdaptiveSheetScaffold(
                title: '用户资料',
                children: [Text('body')],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('用户资料'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });
}

void _noop() {}
