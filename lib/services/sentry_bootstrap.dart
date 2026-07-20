import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env_config.dart';
import 'sentry_event_filter.dart';
import 'talker.dart';

/// Initialize Sentry when [EnvConfig.sentryEnabled]; no-op otherwise.
///
/// Does not wrap [runApp] in `appRunner` — the app still runs its Drift/HTTP
/// startup chain before [runApp].  Error hooks are subsequently installed by
/// [main]'s `_setupErrorHub` which chains into the Sentry handler.
Future<void> initSentryIfEnabled() async {
  if (!EnvConfig.sentryEnabled) return;

  try {
    final release = await _resolveRelease();
    await SentryFlutter.init(
      (options) {
        options.dsn = EnvConfig.sentryDsn;
        options.tracesSampleRate = EnvConfig.sentryTracesSampleRate;
        options.environment = kReleaseMode ? 'production' : 'debug';
        options.release = release;
        options.sendDefaultPii = false;
        options.beforeSend = (event, hint) => filterSentryEvent(
              event,
              hint,
              debugUploadAllowed: EnvConfig.sentryDebugUpload,
            );
      },
    );
  } catch (e, st) {
    talker.handle(e, st, 'Sentry init skipped');
  }
}

Future<String> _resolveRelease() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 's1er@${info.version}+${info.buildNumber}';
  } catch (e, st) {
    talker.handle(e, st, 'Sentry release fallback');
    return 's1er@unknown';
  }
}

/// Report [error] when Sentry is enabled; never throws.
Future<void> captureSentryException(
  Object error,
  StackTrace stackTrace, {
  String? hint,
}) async {
  if (!EnvConfig.sentryEnabled) return;
  try {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint != null ? Hint.withMap({'context': hint}) : null,
    );
  } catch (e, st) {
    talker.handle(e, st, 'Sentry.captureException failed');
  }
}
