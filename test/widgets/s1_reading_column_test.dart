import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/window_size.dart';
import 'package:s1er/widgets/s1_reading_column.dart';

void main() {
  testWidgets('S1ReadingColumn constrains width to reading measure',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ReadingColumn(
            child: SizedBox(key: ValueKey('reading')),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('reading'))).width,
      S1Breakpoints.contentWidthReading,
    );
  });

  testWidgets('ReadingColumnScope exposes geometry for descendants',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ReadingColumnGeometry? captured;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ReadingColumn(
            child: Builder(
              builder: (context) {
                captured = ReadingColumnScope.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(captured, isNotNull);
    expect(captured!.columnWidth, S1Breakpoints.contentWidthReading);
    expect(captured!.horizontalInset, closeTo(240, 0.01));
  });

  testWidgets('showPaneGutter paints page canvas inside reading column',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ReadingColumn(
            showPaneGutter: true,
            child: SizedBox.expand(key: ValueKey('inner')),
          ),
        ),
      ),
    );

    final innerElement = tester.element(find.byKey(const ValueKey('inner')));
    final colored =
        innerElement.findAncestorWidgetOfExactType<ColoredBox>()?.color;
    final scheme = AppTheme.lightTheme('purple').colorScheme;
    expect(colored, S1Surface.page(scheme));
  });

  testWidgets('showPaneGutter paints side strips without full-pane overlay',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ReadingColumn(
            showPaneGutter: true,
            child: SizedBox(key: ValueKey('inner')),
          ),
        ),
      ),
    );

    final scheme = AppTheme.lightTheme('purple').colorScheme;
    final gutterBoxes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color == scheme.surfaceContainer)
        .length;
    expect(gutterBoxes, 2);
  });
}
