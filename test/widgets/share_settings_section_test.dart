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

    final card = find.descendant(
      of: find.byType(ShareSettingsSection),
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _wrapShareSettings(
        child: const Scaffold(
          body: SingleChildScrollView(child: ShareSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('高级导出'), findsOneWidget);
    expect(find.text('显示二维码'), findsOneWidget);

    final qrSwitch = find.widgetWithText(SwitchListTile, '显示二维码');
    final advancedSwitch = find.widgetWithText(SwitchListTile, '高级导出');
    expect(tester.widget<SwitchListTile>(qrSwitch).value, isTrue);
    expect(tester.widget<SwitchListTile>(advancedSwitch).value, isFalse);

    await tester.tap(advancedSwitch);
    await tester.pumpAndSettle();

    expect(find.text('开启高级导出'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, '高级导出'),
          )
          .value,
      isFalse,
    );

    await tester.tap(find.widgetWithText(SwitchListTile, '高级导出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, '高级导出'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('QR switch toggles shareShowQr without a confirm dialog',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
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
              return const Scaffold(
                body: SingleChildScrollView(child: ShareSettingsSection()),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final qrSwitch = find.widgetWithText(SwitchListTile, '显示二维码');
    expect(tester.widget<SwitchListTile>(qrSwitch).value, isTrue);

    await tester.tap(qrSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(qrSwitch).value, isFalse);
    expect(container.read(settingsProvider).shareShowQr, isFalse);
    expect(find.text('开启高级导出'), findsNothing);
  });
}
