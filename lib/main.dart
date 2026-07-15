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

  if (EnvConfig.sentryEnabled) {
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = EnvConfig.sentryDsn;
          options.tracesSampleRate = 0.2;
        },
      );
    } catch (e, st) {
      // Sentry is optional — don't let it block startup.
      talker.handle(e, st, 'Sentry init skipped');
    }
  }

  // ── Web error handlers: log to console, don't crash silently ──────
  if (kIsWeb) {
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is AssertionError &&
          exception.message
              .toString()
              .contains('ViewInsets cannot be negative')) {
        return;
      }
      // Log to browser console so the user can copy-paste the error.
      // ignore: avoid_print — intentional console logging for debugging.
      print('FlutterError: $exception\n${details.stack}');
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is AssertionError &&
          error.message.toString().contains('ViewInsets cannot be negative')) {
        return true;
      }
      // Log to browser console so the user can see the error.
      // ignore: avoid_print — intentional console logging for debugging.
      print('FATAL: $error\n$stack');
      return true; // Prevent silent crash — error is now visible in console.
    };
  }

  AppLocalData? localData;

  try {
    final db = AppDatabase();
    localData = AppLocalData(db);
    await localData.loadEssentials();
  } catch (e, st) {
    talker.handle(e, st, 'App database init failed');
    runApp(_InitErrorApp(error: '$e'));
    return;
  }

  await _loadEmoticonManifest();

  final container = ProviderContainer(
    overrides: [
      localDataProvider.overrideWithValue(localData),
    ],
  );

  try {
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
          requestFilter: EnvConfig.talkerLogAll ? null : (_) => false,
          responseFilter: EnvConfig.talkerLogAll ? null : (_) => false,
        ),
      ),
    );
  } catch (e, st) {
    talker.handle(e, st, 'HTTP client init failed');
    runApp(_InitErrorApp(error: '$e'));
    return;
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const S1App(),
    ),
  );
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
