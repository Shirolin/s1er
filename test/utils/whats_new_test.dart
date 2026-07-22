import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/whats_new_entry.dart';
import 'package:s1er/services/whats_new_catalog.dart';
import 'package:s1er/utils/whats_new_store.dart';

import '../helpers/test_local_data.dart';

void main() {
  group('WhatsNewEntry.fromJson', () {
    test('parses version date and highlights', () {
      final entry = WhatsNewEntry.fromJson({
        'version': '1.2.3',
        'date': '2026-07-22',
        'highlights': ['A', '  B  ', '', null],
      });
      expect(entry.version, '1.2.3');
      expect(entry.date, '2026-07-22');
      expect(entry.highlights, ['A', 'B']);
    });

    test('requires version', () {
      expect(
        () => WhatsNewEntry.fromJson({'highlights': <String>[]}),
        throwsFormatException,
      );
    });
  });

  group('WhatsNewCatalog.parseCatalogJson', () {
    test('parses and sorts newest first', () {
      const raw = '''
{
  "entries": [
    {"version": "0.1.0", "date": "2026-01-01", "highlights": ["old"]},
    {"version": "0.2.0", "date": "2026-02-01", "highlights": ["new"]}
  ]
}
''';
      final entries = WhatsNewCatalog.parseCatalogJson(raw);
      expect(entries.map((e) => e.version), ['0.2.0', '0.1.0']);
    });

    test('rejects bad root', () {
      expect(
        () => WhatsNewCatalog.parseCatalogJson('[]'),
        throwsFormatException,
      );
    });
  });

  group('WhatsNewCatalog.filterInRange', () {
    final entries = [
      const WhatsNewEntry(version: '0.3.0', date: '', highlights: ['c']),
      const WhatsNewEntry(version: '0.2.0', date: '', highlights: ['b']),
      const WhatsNewEntry(version: '0.1.0', date: '', highlights: ['a']),
    ];

    test('returns (seen, current]', () {
      final result = WhatsNewCatalog.filterInRange(
        entries,
        seenVersion: '0.1.0',
        currentVersion: '0.2.0',
      );
      expect(result.map((e) => e.version), ['0.2.0']);
    });

    test('includes multiple when crossing versions', () {
      final result = WhatsNewCatalog.filterInRange(
        entries,
        seenVersion: '0.1.0',
        currentVersion: '0.3.0',
      );
      expect(result.map((e) => e.version), ['0.3.0', '0.2.0']);
    });

    test('empty when nothing in range', () {
      final result = WhatsNewCatalog.filterInRange(
        entries,
        seenVersion: '0.3.0',
        currentVersion: '0.3.0',
      );
      expect(result, isEmpty);
    });
  });

  group('WhatsNewCatalog.load', () {
    testWidgets('loads from asset bundle', (tester) async {
      const raw = '''
{
  "entries": [
    {"version": "1.0.0", "date": "2026-01-01", "highlights": ["hi"]}
  ]
}
''';
      final catalog = WhatsNewCatalog(
        bundle: _StringAssetBundle({
          WhatsNewCatalog.defaultAssetPath: raw,
        }),
      );
      await catalog.load();
      expect(catalog.entries, hasLength(1));
      expect(catalog.entries.first.version, '1.0.0');
    });

    testWidgets('bad asset yields empty catalog', (tester) async {
      final catalog = WhatsNewCatalog(
        bundle: _StringAssetBundle({
          WhatsNewCatalog.defaultAssetPath: 'not-json',
        }),
      );
      await catalog.load();
      expect(catalog.isLoaded, isTrue);
      expect(catalog.entries, isEmpty);
    });
  });

  group('decideWhatsNew', () {
    test('fresh install marks silent', () {
      expect(
        decideWhatsNew(seenVersion: null, currentVersion: '0.2.0'),
        WhatsNewDecision.markSeenSilent,
      );
      expect(
        decideWhatsNew(seenVersion: '', currentVersion: '0.2.0'),
        WhatsNewDecision.markSeenSilent,
      );
    });

    test('same version none', () {
      expect(
        decideWhatsNew(seenVersion: '0.2.0', currentVersion: '0.2.0'),
        WhatsNewDecision.none,
      );
    });

    test('upgrade shows prompt', () {
      expect(
        decideWhatsNew(seenVersion: '0.1.0', currentVersion: '0.2.0'),
        WhatsNewDecision.showPrompt,
      );
    });

    test('corrupt seen treats as silent', () {
      expect(
        decideWhatsNew(seenVersion: 'not-a-version', currentVersion: '0.2.0'),
        WhatsNewDecision.markSeenSilent,
      );
    });
  });

  group('WhatsNewStore', () {
    test('seen version round-trip', () async {
      final (db, local) = await openTestLocalData();
      addTearDown(db.close);

      expect(WhatsNewStore.seenVersion(local.settings), isNull);
      WhatsNewStore.setSeenVersion(local.settings, ' 0.2.0 ');
      expect(WhatsNewStore.seenVersion(local.settings), '0.2.0');
    });
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    final encoded = utf8.encode(value);
    return ByteData.view(Uint8List.fromList(encoded).buffer);
  }
}
