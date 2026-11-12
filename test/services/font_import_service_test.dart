import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/font_import_service.dart';
import 'package:s1er/services/settings_store.dart';
import '../helpers/test_local_data.dart';

/// 构造带合法 sfnt 头的假字体（长度可控）。
Uint8List _fakeFont(int length, {int magic = 0x00010000}) {
  final bytes = Uint8List(length);
  ByteData.sublistView(bytes).setUint32(0, magic);
  for (var i = 4; i < length; i++) {
    bytes[i] = i % 251;
  }
  return bytes;
}

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

  group('FontImportService.validateBytes', () {
    test('accepts TrueType / CFF / Apple sfnt headers', () {
      for (final magic in [0x00010000, 0x4F54544F, 0x74727565]) {
        expect(
          () => FontImportService.validateBytes(_fakeFont(1024, magic: magic)),
          returnsNormally,
        );
      }
    });

    test('rejects WOFF and arbitrary bytes', () {
      for (final magic in [0x774F4646 /*wOFF*/, 0x504B0304 /*zip*/]) {
        expect(
          () => FontImportService.validateBytes(_fakeFont(1024, magic: magic)),
          throwsA(isA<FontImportException>()),
        );
      }
    });

    test('rejects files that are too small or too large', () {
      expect(
        () => FontImportService.validateBytes(_fakeFont(8)),
        throwsA(isA<FontImportException>()),
      );
      expect(
        () => FontImportService.validateBytes(_fakeFont(41 * 1024 * 1024)),
        throwsA(isA<FontImportException>()),
      );
    });

    test('exception message is user-facing (no class prefix)', () {
      try {
        FontImportService.validateBytes(_fakeFont(1024, magic: 0x774F4646));
        fail('expected FontImportException');
      } on FontImportException catch (e) {
        expect(e.toString(), isNot(contains('FontImportException')));
        expect(e.toString(), contains('字体文件'));
      }
    });
  });

  group('FontImportService.familyFor', () {
    test('is stable for identical bytes and changes with content', () {
      final a = _fakeFont(2048);
      final b = Uint8List.fromList(a);
      final c = _fakeFont(2048);
      c[100] = c[100] ^ 0xFF; // 只改内容，不改头部

      expect(FontImportService.familyFor(a), FontImportService.familyFor(b));
      expect(
        FontImportService.familyFor(a),
        isNot(FontImportService.familyFor(c)),
      );
      expect(FontImportService.familyFor(a), startsWith('S1CustomFont_'));
    });

    test('differs when only the length changes', () {
      expect(
        FontImportService.familyFor(_fakeFont(2048)),
        isNot(FontImportService.familyFor(_fakeFont(2049))),
      );
    });

    test('differs when only a middle byte changes', () {
      // 族名必须覆盖全文；按首尾窗口哈希时这一处改动会被漏掉。
      final a = _fakeFont(256 * 1024);
      final b = Uint8List.fromList(a);
      b[128 * 1024] ^= 0xFF;

      expect(
        FontImportService.familyFor(a),
        isNot(FontImportService.familyFor(b)),
      );
    });
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
