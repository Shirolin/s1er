import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/utils/desktop_window.dart';
import 'package:s1er/widgets/settings/desktop_settings_section.dart';

import '../helpers/test_theme.dart';

void main() {
  tearDown(() {
    S1DesktopWindow.supportedOverride = null;
  });

  testWidgets('hidden when the platform has no desktop window', (tester) async {
    S1DesktopWindow.supportedOverride = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
        ],
        child: wrapWithAppTheme(const DesktopSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('桌面窗口'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('desktop shows the close-to-tray switch and persists toggles',
      (tester) async {
    S1DesktopWindow.supportedOverride = true;
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithAppTheme(const DesktopSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('桌面窗口'), findsOneWidget);
    expect(find.text('关闭窗口时最小化到托盘'), findsOneWidget);
    expect(container.read(settingsProvider).closeToTray, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).closeToTray, isTrue);
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isTrue);
  });
}
