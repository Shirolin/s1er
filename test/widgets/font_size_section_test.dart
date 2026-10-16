import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/widgets/settings/font_size_section.dart';

import '../helpers/test_theme.dart';

Widget _wrapFontSizeSection({
  required Widget child,
  AppSettings initial = const AppSettings(),
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        () => SettingsNotifier(initial: initial),
      ),
    ],
    child: wrapWithAppTheme(child),
  );
}

void main() {
  testWidgets('FontSizeSection renders 5 segments and selects font size 20',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _wrapFontSizeSection(
        child: const Scaffold(body: FontSizeSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text('大'), findsOneWidget);
    expect(find.text('超大'), findsOneWidget);
    expect(find.text('特大'), findsOneWidget);

    final segmentedButton = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segmentedButton.segments.length, 5);
    expect(segmentedButton.selected, {14});

    await tester.tap(find.text('特大'));
    await tester.pumpAndSettle();

    final updatedButton = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(updatedButton.selected, {20});
  });

  testWidgets('FontSizeSection stays overflow-free on narrow screens (320dp)',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _wrapFontSizeSection(
        child: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: FontSizeSection(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final buttonFinder = find.byType(SegmentedButton<int>);
    expect(buttonFinder, findsOneWidget);
    final buttonSize = tester.getSize(buttonFinder);
    expect(buttonSize.width, lessThanOrEqualTo(288.0));
  });
}
