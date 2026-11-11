import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/desktop_icon_service.dart';
import 'package:s1er/widgets/settings/desktop_icon_settings_section.dart';

import '../helpers/test_theme.dart';

class _FakeDesktopIconService extends DesktopIconService {
  DesktopShortcutStatus status = DesktopShortcutStatus.missing;
  bool applyResult = true;
  final List<String> appliedIds = <String>[];

  @override
  Future<bool> apply(String iconId) async {
    appliedIds.add(iconId);
    return applyResult;
  }

  @override
  Future<DesktopShortcutStatus> shortcutStatus() async => status;

  @override
  Future<DesktopShortcutResult> createShortcut(String iconId) async {
    status = DesktopShortcutStatus.ours;
    return DesktopShortcutResult.created;
  }

  @override
  Future<DesktopShortcutResult> removeShortcut() async {
    status = DesktopShortcutStatus.missing;
    return DesktopShortcutResult.removed;
  }
}

Widget _wrap(Widget child, ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: wrapWithAppTheme(child),
  );
}

void main() {
  tearDown(() {
    DesktopIconService.supportedOverride = null;
    DesktopIconService.testInstance = null;
  });

  testWidgets('hidden when the platform is not Windows', (tester) async {
    DesktopIconService.supportedOverride = false;

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(const DesktopIconSettingsSection(), container),
    );
    await tester.pumpAndSettle();

    expect(find.text('桌面图标'), findsNothing);
  });

  testWidgets('switches theme and manages the desktop shortcut',
      (tester) async {
    DesktopIconService.supportedOverride = true;
    final service = _FakeDesktopIconService();
    DesktopIconService.testInstance = service;

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(const DesktopIconSettingsSection(), container),
    );
    await tester.pumpAndSettle();

    expect(find.text('桌面图标'), findsOneWidget);
    expect(find.text('创建'), findsOneWidget);

    await tester.tap(find.text('白底'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appIcon, 'white');
    expect(service.appliedIds, ['white']);

    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('已创建桌面快捷方式'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('创建'), findsOneWidget);
    expect(find.text('已删除桌面快捷方式'), findsOneWidget);
  });
}
