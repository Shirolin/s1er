import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/app_exceptions.dart';
import 'package:s1er/models/app_update_manifest.dart';
import 'package:s1er/providers/update_check_provider.dart';
import 'package:s1er/providers/update_download_provider.dart';
import 'package:s1er/services/app_update_downloader.dart';
import 'package:s1er/services/app_update_installer.dart';

void main() {
  final manifest = AppUpdateManifest.fromJson({
    'latest': '2.0.0',
    'minSupported': '1.0.0',
    'notes': '',
    'publishedAt': '2026-07-17',
    'channels': {
      'github': 'https://github.com/Shirolin/s1er/releases/latest',
      'androidApk':
          'https://github.com/Shirolin/s1er/releases/download/v2/app.apk',
    },
  });

  UpdateEvaluation evaluation() {
    return UpdateEvaluation(
      availability: UpdateAvailability.optional,
      localVersion: '1.0.0',
      manifest: manifest,
      downloadUrl:
          'https://github.com/Shirolin/s1er/releases/download/v2/app.apk',
      canInAppDownload: true,
      shouldShowDialog: true,
    );
  }

  test('startInAppUpdate ignores concurrent calls while busy', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final downloader = _SlowDownloader();
    final container = ProviderContainer(
      overrides: [
        appUpdateDownloaderProvider.overrideWithValue(downloader),
        appUpdateInstallerProvider.overrideWithValue(_MockInstaller()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(updateDownloadProvider.notifier);
    final eval = evaluation();

    final first = notifier.startInAppUpdate(eval);
    final second = notifier.startInAppUpdate(eval);
    await Future.wait([first, second]);

    expect(downloader.callCount, 1);
  });

  test('unsupported platform throws before busy and leaves idle', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        appUpdateInstallerProvider.overrideWithValue(_UnsupportedInstaller()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(updateDownloadProvider.notifier);

    await expectLater(
      () => notifier.startInAppUpdate(evaluation()),
      throwsA(
        isA<UpdateCheckException>().having(
          (e) => e.message,
          'message',
          '当前平台不支持应用内安装',
        ),
      ),
    );
    expect(
      container.read(updateDownloadProvider).phase,
      UpdateDownloadPhase.idle,
    );
  });

  test('dispose during permission check completes without throwing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final completer = Completer<bool>();
    final container = ProviderContainer(
      overrides: [
        appUpdateInstallerProvider.overrideWithValue(
          _HangingInstaller(completer),
        ),
      ],
    );

    final notifier = container.read(updateDownloadProvider.notifier);
    final future = notifier.startInAppUpdate(evaluation());

    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(updateDownloadProvider).phase,
      UpdateDownloadPhase.downloading,
    );

    container.dispose();
    completer.complete(true);
    await expectLater(future, completes);

    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    expect(fresh.read(updateDownloadProvider).phase, UpdateDownloadPhase.idle);
  });

  test('invalid windows zip fails without downloading', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final downloader = _SlowDownloader();
    final container = ProviderContainer(
      overrides: [
        appUpdateDownloaderProvider.overrideWithValue(downloader),
      ],
    );
    addTearDown(container.dispose);

    final eval = UpdateEvaluation(
      availability: UpdateAvailability.optional,
      localVersion: '1.0.0',
      manifest: AppUpdateManifest.fromJson({
        'latest': '2.0.0',
        'minSupported': '1.0.0',
        'notes': '',
        'publishedAt': '2026-07-17',
        'channels': {
          'windows':
              'https://github.com/Shirolin/s1er/releases/download/v2/app.exe',
        },
      }),
      downloadUrl:
          'https://github.com/Shirolin/s1er/releases/download/v2/app.exe',
      canInAppDownload: true,
      shouldShowDialog: true,
    );

    await container
        .read(updateDownloadProvider.notifier)
        .startInAppUpdate(eval);

    expect(downloader.callCount, 0);
    expect(
      container.read(updateDownloadProvider).phase,
      UpdateDownloadPhase.failed,
    );
    expect(
      container.read(updateDownloadProvider).message,
      '没有可用的下载地址',
    );
  });
}

class _SlowDownloader extends AppUpdateDownloader {
  int callCount = 0;

  @override
  Future<AppUpdateDownloadResult> downloadApk({
    required List<String> urls,
    required String versionLabel,
    void Function(double progress)? onProgress,
    String extension = 'apk',
  }) async {
    callCount++;
    onProgress?.call(0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    onProgress?.call(1);
    return const AppUpdateDownloadResult(
      filePath: '/tmp/updates/s1er-2.0.0.apk',
      sourceUrl:
          'https://github.com/Shirolin/s1er/releases/download/v2/app.apk',
    );
  }
}

class _MockInstaller extends AppUpdateInstaller {
  _MockInstaller() : super(platform: TargetPlatform.android);

  @override
  bool get isSupported => true;

  @override
  Future<bool> canInstallPackages() async => true;

  @override
  Future<void> installApk(String filePath) async {}
}

class _UnsupportedInstaller extends AppUpdateInstaller {
  _UnsupportedInstaller() : super(platform: TargetPlatform.linux);

  @override
  bool get isSupported => false;
}

class _HangingInstaller extends AppUpdateInstaller {
  _HangingInstaller(this._completer) : super(platform: TargetPlatform.android);

  final Completer<bool> _completer;

  @override
  bool get isSupported => true;

  @override
  Future<bool> canInstallPackages() => _completer.future;
}
