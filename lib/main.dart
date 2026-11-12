import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'app.dart';
import 'config/app_icon_catalog.dart';
import 'config/env_config.dart';
import 'theme/app_theme.dart';
import 'models/emoticon_catalog.dart';
import 'providers/settings_provider.dart';
import 'providers/http_event_bridge_provider.dart';
import 'services/app_database.dart';
import 'services/app_local_data.dart';
import 'services/font_import_service.dart';
import 'services/frame_timing_service.dart';
import 'utils/app_messenger.dart';
import 'utils/desktop_tray.dart';
import 'utils/desktop_window.dart';
import 'utils/single_instance.dart';
import 'utils/update_startup_marker.dart';
import 'services/http_client.dart';
import 'services/sentry_bootstrap.dart';
import 'services/sentry_event_filter.dart';
import 'services/talker.dart';
import 'services/windows_portable_updater.dart';
import 'utils/web_reload.dart'
    if (dart.library.js_interop) 'utils/web_reload_web.dart';
import 'utils/web_crash_reporter.dart'
    if (dart.library.js_interop) 'utils/web_crash_reporter_web.dart';

Future<void> _loadEmoticonCatalog() async {
  try {
    final packsRaw =
        await rootBundle.loadString(EmoticonCatalog.packsAssetPath);
    EmoticonCatalog.applyPacksJson(jsonDecode(packsRaw));
  } catch (e, st) {
    talker.handle(e, st, 'Emoticon packs.json load skipped');
  }
  try {
    final raw = await rootBundle.loadString('assets/emoticons/manifest.json');
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      EmoticonCatalog.applyManifest(decoded);
    }
  } catch (e, st) {
    talker.handle(e, st, 'Emoticon manifest load skipped');
  }
}

/// Route [FlutterError] / [PlatformDispatcher] errors to Talker and Sentry.
///
/// Must be called after [initSentryIfEnabled] so that the previous Sentry
/// handler is chained rather than replaced.  Known Web engine noise is
/// skipped for Sentry and for [FlutterError.presentError].
void _setupErrorHub() {
  final prevOnError = FlutterError.onError;
  final prevPlatformError = PlatformDispatcher.instance.onError;
  var loggedDisposedViewNoise = false;

  FlutterError.onError = (details) {
    // Web hot-restart frame loop: mute per-frame Talker / presentError spam.
    if (isFrameLoopEngineNoise(details.exception)) {
      if (!loggedDisposedViewNoise) {
        loggedDisposedViewNoise = true;
        talker.warning(
          'Web engine disposed EngineFlutterView (often after hot restart). '
          'Hard-refresh the browser tab to recover.',
        );
      }
      return;
    }

    talker.handle(details.exception, details.stack, 'FlutterError');

    // Skip Sentry + presentError for known engine noise (e.g. ViewInsets).
    if (isIgnorableSentryNoise(details.exception)) {
      return;
    }

    unawaited(
      captureSentryException(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
    prevOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (isFrameLoopEngineNoise(error)) {
      if (!loggedDisposedViewNoise) {
        loggedDisposedViewNoise = true;
        talker.warning(
          'Web engine disposed EngineFlutterView (often after hot restart). '
          'Hard-refresh the browser tab to recover.',
        );
      }
      return true;
    }

    talker.handle(error, stack, 'PlatformDispatcher');
    if (!isIgnorableSentryNoise(error)) {
      unawaited(captureSentryException(error, stack));
    }
    persistInitError('$error');
    return prevPlatformError?.call(error, stack) ?? true;
  };
}

void main() async {
  // 覆盖更新交接：新进程启动早期先向旧进程报「已启动」，越早越好。
  reportUpdateStartedIfRequested();

  // One copy per user: a second instance would add a second tray icon and open
  // the same database. Update-launched processes skip the duplicate check — the
  // copy they replace is still alive until it sees the start marker — but keep
  // the mutex so they stay the only instance afterwards.
  S1SingleInstance.ensurePrimary(updateHandoff: isUpdateLaunched());

  WidgetsFlutterBinding.ensureInitialized();

  // Desktop: hide native title bar before first frame (Windows / macOS / Linux).
  await S1DesktopWindow.ensureInitialized();

  // ── Check for persisted crash from a previous broken run ─────────
  if (kIsWeb) {
    final persisted = readPersistedInitError();
    if (persisted != null) {
      runApp(_InitErrorApp(error: persisted));
      return;
    }
  }

  await initSentryIfEnabled();

  // ── Init chain: persist to localStorage on failure ───────────────
  //     Error hub is set up after successful init so that Talker and
  //     Sentry both receive framework / platform errors from here on.
  try {
    final db = AppDatabase();
    final localData = AppLocalData(db);
    await localData.loadEssentials();
    await _loadEmoticonCatalog();

    // 自定义字体必须在首帧构建主题前注册：主题按 activeFamily 选族，
    // 而 FontLoader.load() 不会触发重建，晚加载会让首帧回退到系统字体。
    final fontRestore = await FontImportService.tryRestoreFont();

    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(localData),
      ],
    );

    // 字体文件失效：清掉持久化设置，避免设置页仍显示「已启用自定义字体」
    // 而主题其实在用系统字体。读失败（IO）不算失效——文件与设置都保留，
    // 下次启动重试，只提示本次回退。
    String? fontRestoreNotice;
    if (container.read(settingsProvider).customFontFileName != null) {
      switch (fontRestore) {
        case FontRestoreResult.invalid:
          container.read(settingsProvider.notifier).removeCustomFont();
          fontRestoreNotice = '自定义字体加载失败，已回退系统默认字体';
        case FontRestoreResult.missing:
          container.read(settingsProvider.notifier).removeCustomFont();
          fontRestoreNotice = '自定义字体文件不存在，已回退系统默认字体';
        case FontRestoreResult.unreadable:
          fontRestoreNotice = '自定义字体读取失败，本次使用系统默认字体';
        case FontRestoreResult.restored:
          break;
      }
    }

    final httpClient = container.read(httpClientProvider);
    await httpClient.init();
    httpClient.dio.interceptors.add(
      TalkerDioLogger(
        talker: talker,
        settings: TalkerDioLoggerSettings(
          printRequestData: false,
          printRequestHeaders: false,
          printResponseData: false,
          printResponseHeaders: false,
          printResponseMessage: true,
          printErrorData: false,
          printErrorHeaders: false,
          hiddenHeaders: const {'cookie', 'Cookie', 'set-cookie', 'Set-Cookie'},
          requestFilter: EnvConfig.talkerLogAll ? null : (_) => false,
          responseFilter: EnvConfig.talkerLogAll ? null : (_) => false,
        ),
      ),
    );

    // Align launcher icon with persisted setting (Android / iOS only).
    unawaited(
      container.read(settingsProvider.notifier).syncAppIconWithNative(),
    );

    // A successful overlay update leaves the previous build's files renamed to
    // `*.s1erold`; the process that held them has exited by now.
    unawaited(WindowsPortableUpdater().cleanupAfterUpdate());

    // Desktop tray: keep the app reachable while its window is hidden.
    if (S1DesktopTray.isSupported) {
      final settings = container.read(settingsProvider);
      unawaited(
        DesktopTrayController.instance.initialize(
          closeToTray: settings.closeToTray,
          showIcon: settings.showTrayIcon,
          iconAsset: AppIconCatalog.previewAssetFor(settings.appIcon),
        ),
      );
    }

    // 订阅 HTTP 事件（未读计数 / 服务器公告）；客户端只转发、由适配器落库。
    container.read(httpEventBridgeProvider);

    _setupErrorHub();

    // 掉帧统计进 Talker（仅掉帧秒打点）；App 内版本行点 5 下可查看。
    // 正式版不注册：release 零开销，卡顿排查改用 --profile。
    if (!kReleaseMode) {
      FrameTimingService.instance.register();
    }

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const S1App(),
      ),
    );

    // 已回退到系统字体：让用户知道原因。
    if (fontRestoreNotice != null) {
      final notice = fontRestoreNotice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        s1MessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(notice)),
        );
      });
    }
  } catch (e, st) {
    talker.handle(e, st, 'App init failed');
    await captureSentryException(e, st, hint: 'App init failed');
    if (kIsWeb) {
      persistInitError('$e');
    }
    runApp(_InitErrorApp(error: '$e'));
  }
}

class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme(AppTheme.defaultThemeColorKey),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '应用初始化失败',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                Text(
                  '请刷新页面重试',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => reloadApp(),
                  child: const Text('刷新重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
