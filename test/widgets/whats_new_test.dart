import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1er/models/app_update_manifest.dart';
import 'package:s1er/models/whats_new_entry.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/talker_provider.dart';
import 'package:s1er/providers/update_check_provider.dart';
import 'package:s1er/providers/whats_new_provider.dart';
import 'package:s1er/services/whats_new_catalog.dart';
import 'package:s1er/widgets/settings/about_settings_section.dart';
import 'package:s1er/widgets/whats_new_dialog.dart';
import 'package:s1er/widgets/whats_new_prompt_host.dart';

import '../helpers/test_local_data.dart';
import '../helpers/test_theme.dart';

void main() {
  const catalogJson = '''
{
  "entries": [
    {"version": "0.2.0", "date": "2026-07-19", "highlights": ["分享卡导出"]},
    {"version": "0.1.0", "date": "2026-07-15", "highlights": ["首次发布"]}
  ]
}
''';

  testWidgets('About section shows changelog tile', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'S1er',
              packageName: 'dev.s1er',
              version: '0.2.0',
              buildNumber: '1',
            ),
          ),
        ],
        child: wrapWithAppTheme(const AboutSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('更新日志'), findsOneWidget);
    await tester.tap(find.text('更新日志'));
    await tester.pumpAndSettle();
    expect(find.text('更新日志'), findsWidgets);
  });

  testWidgets('Whats New dialog shows highlights', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () {
                showWhatsNewDialog(
                  context,
                  entries: const [
                    WhatsNewEntry(
                      version: '0.2.0',
                      date: '2026-07-19',
                      highlights: ['分享卡导出'],
                    ),
                  ],
                  onDismissed: () {},
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('新功能'), findsOneWidget);
    expect(find.textContaining('分享卡导出'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
  });

  testWidgets('PromptHost defers while update pendingPrompt set',
      (tester) async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);

    final catalog = WhatsNewCatalog(
      bundle: _StringAssetBundle({
        WhatsNewCatalog.defaultAssetPath: catalogJson,
      }),
    );

    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(),
            store: local.settings,
          ),
        ),
        packageInfoProvider.overrideWith(
          (_) async => PackageInfo(
            appName: 'S1er',
            packageName: 'dev.s1er',
            version: '0.2.0',
            buildNumber: '1',
          ),
        ),
        whatsNewCatalogProvider.overrideWithValue(catalog),
      ],
    );
    addTearDown(container.dispose);

    final manifest = AppUpdateManifest.fromJson({
      'latest': '9.0.0',
      'minSupported': '0.1.0',
      'notes': 'remote',
      'publishedAt': '2026-07-22',
      'channels': {
        'github': 'https://github.com/Shirolin/s1er/releases/latest',
      },
    });
    final evaluation = UpdateEvaluation(
      availability: UpdateAvailability.optional,
      localVersion: '0.2.0',
      manifest: manifest,
      downloadUrl: 'https://example.com',
      shouldShowDialog: true,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithAppTheme(
          const WhatsNewPromptHost(
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Seed after host is mounted so ref.listen fires.
    // Update prompt first so the deferred tryShow sees it.
    container.read(updateCheckProvider.notifier).debugSetStartupPrompt(
          pendingPrompt: evaluation,
        );
    container.read(whatsNewProvider.notifier).debugSetPendingEntries(const [
      WhatsNewEntry(
        version: '0.2.0',
        date: '2026-07-19',
        highlights: ['分享卡导出'],
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Upgrade dialog not hosted here; What's New must wait.
    expect(find.text('新功能'), findsNothing);
    expect(find.textContaining('分享卡导出'), findsNothing);

    container.read(updateCheckProvider.notifier).clearPendingPrompt();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('新功能'), findsOneWidget);
    expect(find.textContaining('分享卡导出'), findsOneWidget);
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
