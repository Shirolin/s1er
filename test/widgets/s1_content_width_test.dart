import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_content_width.dart';

void main() {
  Future<void> pumpAtWidth(
    WidgetTester tester, {
    required double width,
    required S1ContentWidthMode mode,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ContentWidth(
            mode: mode,
            child: const SizedBox.expand(key: ValueKey('content')),
          ),
        ),
      ),
    );
  }

  testWidgets('standard content uses the large-screen maximum width',
      (tester) async {
    await pumpAtWidth(
      tester,
      width: 1200,
      mode: S1ContentWidthMode.standard,
    );

    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 1040);
  });

  testWidgets('reading and form content use their narrower maximum widths',
      (tester) async {
    await pumpAtWidth(
      tester,
      width: 1200,
      mode: S1ContentWidthMode.reading,
    );
    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 840);

    await pumpAtWidth(
      tester,
      width: 1200,
      mode: S1ContentWidthMode.form,
    );
    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 720);
  });
}
