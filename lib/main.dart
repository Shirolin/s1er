import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'app.dart';
import 'config/env_config.dart';
import 'theme/app_theme.dart';
import 'models/emoticon_catalog.dart';
import 'providers/settings_provider.dart';
import 'services/app_database.dart';
import 'services/app_local_data.dart';
import 'utils/desktop_window.dart';
import 'services/http_client.dart';
import 'services/sentry_bootstrap.dart';
import 'services/sentry_event_filter.dart';
import 'services/talker.dart';
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

  FlutterError.onError = (details) {
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
    talker.handle(error, stack, 'PlatformDispatcher');
    if (!isIgnorableSentryNoise(error)) {
      unawaited(captureSentryException(error, stack));
    }
    persistInitError('$error');
    return prevPlatformError?.call(error, stack) ?? true;
  };
}

void main() async {
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

    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(localData),
      ],
    );

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

    _setupErrorHub();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const S1App(),
      ),
    );
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
