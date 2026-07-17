import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/talker_provider.dart';
import 'package:s1er/providers/update_check_provider.dart';
import 'package:s1er/services/update_check_service.dart';
import 'package:s1er/widgets/settings/about_settings_section.dart';

import '../helpers/test_local_data.dart';
import '../helpers/test_theme.dart';

void main() {
  testWidgets('About check update shows dialog when update available', (
    tester,
  ) async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);

    final payload = {
      'latest': '2.0.0',
      'minSupported': '1.0.0',
      'notes': '测试说明',
      'publishedAt': '2026-07-17',
      'channels': {
        'github': 'https://github.com/Shirolin/s1-app/releases/latest',
      },
    };
    final dio = Dio()..httpClientAdapter = _JsonAdapter(payload);

    await tester.pumpWidget(
      ProviderScope(
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
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
          updateCheckServiceProvider.overrideWithValue(
            UpdateCheckService(
              dio: dio,
              manifestUrl: 'https://example.com/latest.json',
            ),
          ),
        ],
        child: wrapWithAppTheme(const AboutSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('检查更新'), findsOneWidget);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('去更新'), findsOneWidget);
    expect(find.text('忽略此版'), findsOneWidget);
    expect(find.textContaining('测试说明'), findsOneWidget);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.payload);

  final Map<String, dynamic> payload;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
