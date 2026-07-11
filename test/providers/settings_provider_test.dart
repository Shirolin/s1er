import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('s1_settings_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.box('settings').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('resetAppearanceSettings restores defaults only for appearance prefs',
      () {
    final notifier = SettingsNotifier(
      const AppSettings(
        themeMode: 'dark',
        themeColor: 'green',
        showImages: false,
        recordReadingHistory: false,
        fontSize: 18,
        useDynamicColor: true,
        collapsedForums: {'42'},
      ),
    );

    notifier.resetAppearanceSettings();

    expect(notifier.state.themeMode, 'system');
    expect(notifier.state.themeColor, 'purple');
    expect(notifier.state.showImages, isTrue);
    expect(notifier.state.recordReadingHistory, isTrue);
    expect(notifier.state.fontSize, S1Typography.defaultBodySize);
    expect(notifier.state.useDynamicColor, isFalse);
    expect(notifier.state.collapsedForums, const {'42'});
  });

  test('setRecordReadingHistory persists to Hive', () {
    final notifier = SettingsNotifier(const AppSettings());

    notifier.setRecordReadingHistory(false);

    expect(notifier.state.recordReadingHistory, isFalse);
    expect(Hive.box('settings').get('recordReadingHistory'), isFalse);
  });
}
