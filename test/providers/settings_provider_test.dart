import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(
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
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).resetAppearanceSettings();
    final state = container.read(settingsProvider);

    expect(state.themeMode, 'system');
    expect(state.themeColor, 'purple');
    expect(state.showImages, isTrue);
    expect(state.recordReadingHistory, isTrue);
    expect(state.fontSize, S1Typography.defaultBodySize);
    expect(state.useDynamicColor, isFalse);
    expect(state.collapsedForums, const {'42'});
  });

  test('setRecordReadingHistory persists to settings store', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).setRecordReadingHistory(false);

    expect(container.read(settingsProvider).recordReadingHistory, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<bool>('recordReadingHistory'), isFalse);
  });
}
