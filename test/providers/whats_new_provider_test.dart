import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/talker_provider.dart';
import 'package:s1er/providers/update_check_provider.dart';
import 'package:s1er/providers/whats_new_provider.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/whats_new_catalog.dart';
import 'package:s1er/utils/whats_new_store.dart';

import '../helpers/test_local_data.dart';

void main() {
  const catalogJson = '''
{
  "entries": [
    {"version": "0.2.0", "date": "2026-07-19", "highlights": ["feat"]},
    {"version": "0.1.0", "date": "2026-07-15", "highlights": ["init"]}
  ]
}
''';

  ProviderContainer buildContainer({
    required AppLocalData local,
    required String version,
    String? seenVersion,
  }) {
    if (seenVersion != null) {
      WhatsNewStore.setSeenVersion(local.settings, seenVersion);
    }
    final catalog = WhatsNewCatalog(
      bundle: _StringAssetBundle({
        WhatsNewCatalog.defaultAssetPath: catalogJson,
      }),
    );

    return ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
        packageInfoProvider.overrideWith(
          (_) async => PackageInfo(
            appName: 'S1er',
            packageName: 'dev.s1er',
            version: version,
            buildNumber: '1',
          ),
        ),
        whatsNewCatalogProvider.overrideWithValue(catalog),
      ],
    );
  }

  Future<void> settleUpdate(ProviderContainer container) async {
    container.read(updateCheckProvider.notifier).debugSetStartupPrompt();
  }

  test('fresh install marks seen silently', () async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);

    final container = buildContainer(local: local, version: '0.2.0');
    addTearDown(container.dispose);

    await settleUpdate(container);
    await container
        .read(whatsNewProvider.notifier)
        .runStartupCheck(delay: Duration.zero);

    expect(container.read(whatsNewProvider).pendingEntries, isNull);
    expect(WhatsNewStore.seenVersion(local.settings), '0.2.0');
  });

  test('upgrade queues pending entries', () async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);

    final container = buildContainer(
      local: local,
      version: '0.2.0',
      seenVersion: '0.1.0',
    );
    addTearDown(container.dispose);

    await settleUpdate(container);
    await container
        .read(whatsNewProvider.notifier)
        .runStartupCheck(delay: Duration.zero);

    final pending = container.read(whatsNewProvider).pendingEntries;
    expect(pending, isNotNull);
    expect(pending!.map((e) => e.version), ['0.2.0']);
  });

  test('same version does not prompt', () async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);

    final container = buildContainer(
      local: local,
      version: '0.2.0',
      seenVersion: '0.2.0',
    );
    addTearDown(container.dispose);

    await settleUpdate(container);
    await container
        .read(whatsNewProvider.notifier)
        .runStartupCheck(delay: Duration.zero);

    expect(container.read(whatsNewProvider).pendingEntries, isNull);
  });

  test('markSeenCurrent persists version', () async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);

    final container = buildContainer(
      local: local,
      version: '0.2.0',
      seenVersion: '0.1.0',
    );
    addTearDown(container.dispose);

    await container.read(whatsNewProvider.notifier).markSeenCurrent();
    expect(WhatsNewStore.seenVersion(local.settings), '0.2.0');
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
