import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/settings_store.dart';
import '../helpers/test_local_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late dynamic db;
  late SettingsStore store;

  setUp(() async {
    final opened = await openTestLocalData();
    db = opened.$1;
    store = opened.$2.settings;
  });

  tearDown(() async {
    await db.close();
  });

  test('setCustomFont updates state and persists filename', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);

    expect(container.read(settingsProvider).customFontFileName, null);

    notifier.setCustomFont('MyCustomFont.ttf');

    expect(
      container.read(settingsProvider).customFontFileName,
      'MyCustomFont.ttf',
    );
    expect(
      store.get<String>('customFontFileName'),
      'MyCustomFont.ttf',
    );
  });

  test('removeCustomFont clears custom font state and persisted store', () {
    store.put('customFontFileName', 'MyCustomFont.ttf');

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);

    expect(
      container.read(settingsProvider).customFontFileName,
      'MyCustomFont.ttf',
    );

    notifier.removeCustomFont();

    expect(container.read(settingsProvider).customFontFileName, null);
    expect(store.get<String>('customFontFileName'), null);
  });

  test('resetAppearanceSettings resets custom font setting', () {
    store.put('customFontFileName', 'MyCustomFont.ttf');

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);

    expect(
      container.read(settingsProvider).customFontFileName,
      'MyCustomFont.ttf',
    );

    notifier.resetAppearanceSettings();

    expect(container.read(settingsProvider).customFontFileName, null);
    expect(store.get<String>('customFontFileName'), null);
  });
}
