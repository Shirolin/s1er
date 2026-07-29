import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/widgets/settings/share_settings_section.dart';

import '../helpers/test_theme.dart';

Widget _wrapShareSettings({
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
  testWidgets('ShareSettingsSection fills desktop width and stays compact-safe',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _wrapShareSettings(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: const Column(children: [ShareSettingsSection()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('分享'),
      matching: find.byType(Card),
    );
    expect(tester.getSize(card).width, greaterThan(1000));

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(card).width, lessThanOrEqualTo(360));
  });

  testWidgets('clarity subtitle updates when segmented option changes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _wrapShareSettings(
        child: const Scaffold(body: ShareSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('约 900px 宽，默认推荐'), findsOneWidget);
    expect(find.byType(SharePixelRatioSelector), findsOneWidget);

    final segmentedButtons = tester.widgetList<SegmentedButton<double>>(
      find.byType(SegmentedButton<double>),
    );
    expect(segmentedButtons.length, 1);

    await tester.tap(find.text('高清'));
    await tester.pumpAndSettle();

    expect(find.text('约 1800px 宽，体积最大'), findsOneWidget);
    expect(find.text('约 900px 宽，默认推荐'), findsNothing);
  });

  testWidgets('narrow screen uses dropdown for clarity selection',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
        ],
        child: wrapWithAppTheme(
          Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const Scaffold(body: ShareSettingsSection());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<double>), findsNothing);
    expect(find.byType(DropdownMenu<double>), findsOneWidget);
    expect(find.text('约 900px 宽，默认推荐'), findsOneWidget);

    await tester.tap(find.byType(DropdownMenu<double>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高清 3x（约 1800px）').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).sharePixelRatio, 3.0);
    expect(find.text('约 1800px 宽，体积最大'), findsOneWidget);
  });

  testWidgets('advanced export switch shows confirm dialog before enabling',
      (tester) async {
    await tester.pumpWidget(
      _wrapShareSettings(
        child: const Scaffold(body: ShareSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('高级导出'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);

    final switchWidget = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchWidget.value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('开启高级导出'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });
}
