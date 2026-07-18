import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'config/env_config.dart';
import 'theme/app_theme.dart';
import 'models/emoticon_catalog.dart';
import 'providers/settings_provider.dart';
import 'services/app_database.dart';
import 'services/app_local_data.dart';
import 'services/http_client.dart';
import 'services/talker.dart';
import 'utils/web_reload.dart'
    if (dart.library.js_interop) 'utils/web_reload_web.dart';
import 'utils/web_crash_reporter.dart'
    if (dart.library.js_interop) 'utils/web_crash_reporter_web.dart';

Future<void> _loadEmoticonManifest() async {
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Check for persisted crash from a previous broken run ─────────
  if (kIsWeb) {
    final persisted = readPersistedInitError();
    if (persisted != null) {
      runApp(_InitErrorApp(error: persisted));
      return;
    }
  }

  if (EnvConfig.sentryEnabled) {
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = EnvConfig.sentryDsn;
          options.tracesSampleRate = 0.2;
        },
      );
    } catch (e, st) {
      talker.handle(e, st, 'Sentry init skipped');
    }
  }

  // ── Web error handlers: persist to localStorage + console log ────
  if (kIsWeb) {
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is AssertionError &&
          exception.message
              .toString()
              .contains('ViewInsets cannot be negative')) {
        return;
      }
      // ignore: avoid_print — intentional console logging.
      print('FlutterError: $exception\n${details.stack}');
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is AssertionError &&
          error.message.toString().contains('ViewInsets cannot be negative')) {
        return true;
      }
      // ignore: avoid_print — intentional console logging.
      print('FATAL: $error\n$stack');
      persistInitError('$error');
      return true;
    };
  }

  // ── Init chain: persist to localStorage on failure ───────────────
  try {
    final db = AppDatabase();
    final localData = AppLocalData(db);
    await localData.loadEssentials();
    await _loadEmoticonManifest();

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

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const S1App(),
      ),
    );
  } catch (e, st) {
    talker.handle(e, st, 'App init failed');
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
