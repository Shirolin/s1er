import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/settings_store.dart';
import 'package:s1_app/theme/app_theme.dart';
import '../helpers/test_local_data.dart';

void main() {
  late SettingsStore store;
  late dynamic db;

  setUp(() async {
    final opened = await openTestLocalData();
    db = opened.$1;
    store = opened.$2.settings;
  });

  tearDown(() async {
    await db.close();
  });

  test('resetAppearanceSettings restores defaults only for appearance prefs',
      () {
    final notifier = SettingsNotifier(
      store: store,
      initial: const AppSettings(
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

  test('setRecordReadingHistory persists to settings store', () async {
    final notifier = SettingsNotifier(store: store, initial: const AppSettings());

    notifier.setRecordReadingHistory(false);

    expect(notifier.state.recordReadingHistory, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<bool>('recordReadingHistory'), isFalse);
  });
}
