import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1er/models/app_update_manifest.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/talker_provider.dart';
import 'package:s1er/providers/update_check_provider.dart';
import 'package:s1er/services/update_check_service.dart';
import 'package:s1er/utils/update_prompt_store.dart';

import '../helpers/test_local_data.dart';

void main() {
  final manifestJson = {
    'latest': '2.0.0',
    'minSupported': '1.0.0',
    'notes': '重大更新',
    'publishedAt': '2026-07-17',
    'channels': {
      'github': 'https://github.com/Shirolin/s1er/releases/latest',
    },
  };

  final manifest = AppUpdateManifest.fromJson(manifestJson);

  group('evaluateUpdate', () {
    test('force when below minSupported', () {
      final result = evaluateUpdate(
        localVersion: '0.9.0',
        manifest: manifest,
        downloadUrl: 'https://example.com',
        now: DateTime(2026, 7, 17),
        manual: false,
      );
      expect(result.availability, UpdateAvailability.force);
      expect(result.shouldShowDialog, isTrue);
    });

    test('optional when behind latest', () {
      final result = evaluateUpdate(
        localVersion: '1.5.0',
        manifest: manifest,
        downloadUrl: 'https://example.com',
        now: DateTime(2026, 7, 17),
        manual: false,
      );
      expect(result.availability, UpdateAvailability.optional);
      expect(result.shouldShowDialog, isTrue);
    });

    test('upToDate when current', () {
      final result = evaluateUpdate(
        localVersion: '2.0.0',
        manifest: manifest,
        downloadUrl: 'https://example.com',
        now: DateTime(2026, 7, 17),
        manual: true,
      );
      expect(result.availability, UpdateAvailability.upToDate);
      expect(result.shouldShowDialog, isFalse);
      expect(result.userMessage, '已是最新版本');
    });

    test('respects ignored version for optional', () {
      final result = evaluateUpdate(
        localVersion: '1.5.0',
        manifest: manifest,
        downloadUrl: 'https://example.com',
        ignoredVersion: '2.0.0',
        now: DateTime(2026, 7, 17),
        manual: true,
      );
      expect(result.shouldShowDialog, isFalse);
      expect(result.userMessage, '已忽略此版本的更新提示');
    });

    test('startup respects cooldown for optional on same version', () {
      final now = DateTime(2026, 7, 17);
      final result = evaluateUpdate(
        localVersion: '1.5.0',
        manifest: manifest,
        downloadUrl: 'https://example.com',
        lastPromptVersion: '2.0.0',
        lastPromptMs:
            now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        now: now,
        manual: false,
      );
      expect(result.shouldShowDialog, isFalse);
    });

    test('startup resets cooldown when a newer version is available', () {
      final now = DateTime(2026, 7, 17);
      final newManifest = AppUpdateManifest.fromJson({
        ...manifestJson,
        'latest': '2.1.0',
      });
      final result = evaluateUpdate(
        localVersion: '1.5.0',
        manifest: newManifest,
        downloadUrl: 'https://example.com',
        lastPromptVersion: '2.0.0', // 上次只弹过 2.0.0
        lastPromptMs:
            now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        now: now,
        manual: false,
      );
      expect(result.shouldShowDialog, isTrue);
    });

    test('manual ignores cooldown', () {
      final now = DateTime(2026, 7, 17);
      final result = evaluateUpdate(
        localVersion: '1.5.0',
        manifest: manifest,
        downloadUrl: 'https://example.com',
        lastPromptMs:
            now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        now: now,
        manual: true,
      );
      expect(result.shouldShowDialog, isTrue);
    });

    test('force ignores cooldown and ignored version', () {
      final now = DateTime(2026, 7, 17);
      final forced = AppUpdateManifest.fromJson({
        ...manifestJson,
        'minSupported': '1.9.0',
      });
      final result = evaluateUpdate(
        localVersion: '1.5.0',
        manifest: forced,
        downloadUrl: 'https://example.com',
        ignoredVersion: '2.0.0',
        lastPromptMs: now.millisecondsSinceEpoch,
        now: now,
        manual: false,
      );
      expect(result.availability, UpdateAvailability.force);
      expect(result.shouldShowDialog, isTrue);
    });
  });

  group('UpdateCheckNotifier', () {
    test('checkManual returns optional update', () async {
      final (db, local) = await openTestLocalData();
      addTearDown(db.close);

      final dio = Dio()..httpClientAdapter = _JsonAdapter(manifestJson);
      final container = ProviderContainer(
        overrides: [
          localDataProvider.overrideWithValue(local),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'S1er',
              packageName: 'dev.s1er',
              version: '1.5.0',
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
      );
      addTearDown(container.dispose);

      final evaluation =
          await container.read(updateCheckProvider.notifier).checkManual();
      expect(evaluation.availability, UpdateAvailability.optional);
      expect(evaluation.shouldShowDialog, isTrue);
      expect(evaluation.manifest.latest, '2.0.0');
    });

    test('updateCheckCoordinatorProvider defers startup without build mutation',
        () async {
      final (db, local) = await openTestLocalData();
      addTearDown(db.close);

      final dio = Dio()..httpClientAdapter = _JsonAdapter(manifestJson);
      final container = ProviderContainer(
        overrides: [
          localDataProvider.overrideWithValue(local),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'S1er',
              packageName: 'dev.s1er',
              version: '1.5.0',
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
      );
      addTearDown(container.dispose);

      // Must not assert: Providers cannot modify other providers during build.
      expect(
        () => container.read(updateCheckCoordinatorProvider),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(updateCheckProvider).autoCheckStarted, isTrue);
    });

    test('runStartupCheck sets pendingPrompt', () async {
      final (db, local) = await openTestLocalData();
      addTearDown(db.close);

      final dio = Dio()..httpClientAdapter = _JsonAdapter(manifestJson);
      final container = ProviderContainer(
        overrides: [
          localDataProvider.overrideWithValue(local),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'S1er',
              packageName: 'dev.s1er',
              version: '1.5.0',
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
      );
      addTearDown(container.dispose);

      await container.read(updateCheckProvider.notifier).runStartupCheck(
            delay: Duration.zero,
          );
      final pending = container.read(updateCheckProvider).pendingPrompt;
      expect(pending, isNotNull);
      expect(pending!.availability, UpdateAvailability.optional);
    });

    test('ignoreVersion persists and suppresses optional', () async {
      final (db, local) = await openTestLocalData();
      addTearDown(db.close);

      final dio = Dio()..httpClientAdapter = _JsonAdapter(manifestJson);
      final container = ProviderContainer(
        overrides: [
          localDataProvider.overrideWithValue(local),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'S1er',
              packageName: 'dev.s1er',
              version: '1.5.0',
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
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateCheckProvider.notifier);
      notifier.ignoreVersion('2.0.0');
      expect(
        UpdatePromptStore.ignoredVersion(local.settings),
        '2.0.0',
      );

      final evaluation = await notifier.checkManual();
      expect(evaluation.shouldShowDialog, isFalse);
      expect(evaluation.userMessage, '已忽略此版本的更新提示');
    });

    test(
        'markPromptInteracted with targetVersion persists version and timestamp',
        () async {
      final (db, local) = await openTestLocalData();
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          localDataProvider.overrideWithValue(local),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateCheckProvider.notifier);
      final now = DateTime(2026, 7, 24);
      notifier.markPromptInteracted(
        targetVersion: '2.0.0',
        clock: () => now,
      );

      expect(UpdatePromptStore.lastPromptVersion(local.settings), '2.0.0');
      expect(
        UpdatePromptStore.lastPromptMs(local.settings),
        now.millisecondsSinceEpoch,
      );
    });
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
