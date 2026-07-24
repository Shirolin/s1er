import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/app_update_manifest.dart';
import 'package:s1er/providers/update_check_provider.dart';
import 'package:s1er/providers/update_download_provider.dart';
import 'package:s1er/services/app_update_installer.dart';
import 'package:s1er/widgets/app_update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/test_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppUpdateManifest manifestWith({
    String? androidApk,
    String? androidNetdisk,
    String? netdiskHint,
  }) {
    return AppUpdateManifest.fromJson({
      'latest': '2.0.0',
      'minSupported': '1.0.0',
      'notes': '说明',
      'publishedAt': '2026-07-19',
      'channels': {
        'github': 'https://github.com/Shirolin/s1er/releases/latest',
        if (androidApk != null) 'androidApk': androidApk,
        if (androidNetdisk != null) 'androidNetdisk': androidNetdisk,
        if (netdiskHint != null) 'netdiskHint': netdiskHint,
      },
    });
  }

  UpdateEvaluation evaluationFor(
    AppUpdateManifest manifest, {
    required bool canInApp,
    String downloadUrl = 'https://github.com/Shirolin/s1er/releases/latest',
  }) {
    final netdisk = manifest.channels.androidNetdisk ?? '';
    return UpdateEvaluation(
      availability: UpdateAvailability.optional,
      localVersion: '1.0.0',
      manifest: manifest,
      downloadUrl: downloadUrl,
      netdiskUrl: netdisk.startsWith('https://pan.baidu.com') ? netdisk : '',
      canInAppDownload: canInApp,
      shouldShowDialog: true,
    );
  }

  testWidgets('shows netdisk secondary and 去更新 without in-app', (tester) async {
    final opened = <Uri>[];
    final manifest = manifestWith(
      androidNetdisk: 'https://pan.baidu.com/s/xxxx',
      netdiskHint: '提取码：abcd',
    );
    final evaluation = evaluationFor(manifest, canInApp: false);

    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(
          Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    showAppUpdateDialog(
                      context,
                      evaluation: evaluation,
                      onPromptInteracted: () {},
                      onIgnoreVersion: (_) {},
                      launchUrlFn: (
                        uri, {
                        mode = LaunchMode.platformDefault,
                      }) async {
                        opened.add(uri);
                        return true;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('稍后提醒'), findsOneWidget);
    expect(find.text('忽略此版'), findsOneWidget);
    expect(find.text('网盘下载'), findsOneWidget);
    expect(find.text('去更新'), findsOneWidget);
    expect(find.textContaining('提取码：abcd'), findsOneWidget);
    expect(find.text('立即更新'), findsNothing);
  });

  testWidgets('failed download elevates netdisk as primary CTA',
      (tester) async {
    final manifest = manifestWith(
      androidApk:
          'https://github.com/Shirolin/s1er/releases/download/v2/app.apk',
      androidNetdisk: 'https://pan.baidu.com/s/xxxx',
      netdiskHint: '提取码：zz',
    );
    final evaluation = evaluationFor(
      manifest,
      canInApp: true,
      downloadUrl:
          'https://github.com/Shirolin/s1er/releases/download/v2/app.apk',
    );

    final container = ProviderContainer(
      overrides: [
        updateDownloadProvider.overrideWith(_FailedDownloadNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithAppTheme(
          Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    showAppUpdateDialog(
                      context,
                      evaluation: evaluation,
                      onPromptInteracted: () {},
                      onIgnoreVersion: (_) {},
                      container: container,
                      launchUrlFn: (
                        uri, {
                        mode = LaunchMode.platformDefault,
                      }) async =>
                          true,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('立即更新'), findsOneWidget);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(find.text('下载失败'), findsOneWidget);
    expect(find.textContaining('网络受限'), findsOneWidget);
    expect(find.text('网盘下载'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('浏览器打开'), findsOneWidget);

    // Primary filled netdisk
    final netdiskButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '网盘下载'),
    );
    expect(netdiskButton.onPressed, isNotNull);
  });

  testWidgets('illegal netdisk host hides netdisk button', (tester) async {
    final manifest = manifestWith(
      androidNetdisk: 'https://evil.example/share',
    );
    // evaluationFor only accepts baidu as netdiskUrl
    final evaluation = UpdateEvaluation(
      availability: UpdateAvailability.optional,
      localVersion: '1.0.0',
      manifest: manifest,
      downloadUrl: 'https://github.com/Shirolin/s1er/releases/latest',
      netdiskUrl: '',
      canInAppDownload: false,
      shouldShowDialog: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(
          Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    showAppUpdateDialog(
                      context,
                      evaluation: evaluation,
                      onPromptInteracted: () {},
                      onIgnoreVersion: (_) {},
                      launchUrlFn: (
                        uri, {
                        mode = LaunchMode.platformDefault,
                      }) async =>
                          true,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('网盘下载'), findsNothing);
    expect(find.text('去更新'), findsOneWidget);
  });

  test('AppUpdateInstaller installApk invokes channel', () async {
    const channel = MethodChannel('com.stage1st.s1er/apk_installer');
    final log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      if (call.method == 'canInstallPackages') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final installer = AppUpdateInstaller(
      channel: channel,
      platform: TargetPlatform.android,
    );
    expect(await installer.canInstallPackages(), isTrue);
    await installer.installApk('/tmp/updates/app.apk');
    expect(
      log.map((c) => c.method),
      containsAll(['canInstallPackages', 'installApk']),
    );
  });
}

class _FailedDownloadNotifier extends UpdateDownloadNotifier {
  @override
  Future<void> startAndroidUpdate(UpdateEvaluation evaluation) async {
    state = const UpdateDownloadState(
      phase: UpdateDownloadPhase.failed,
      message: '下载超时',
    );
  }
}
