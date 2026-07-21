import 'package:sentry_flutter/sentry_flutter.dart';

/// Known Flutter Web engine noise that must never become a Sentry issue.
const kSentryViewInsetsNoise = 'ViewInsets cannot be negative';

/// Known SelectableRegion post-frame race (Flutter #125065).
const kSentryDebugNeedsLayout = '!debugNeedsLayout';

/// Known RawTooltip SingleTickerProvider race (rapid pointer events).
const kSentryTooltipTicker =
    'SingleTickerProviderStateMixin but multiple tickers were created';

/// Marker left by legacy / mistaken [FlutterError.reportError] paths.
const kSentryImageViewerLibrary = 'image_viewer_screen';

/// Whether [error] is a known-harmless Web layout quirk.
bool isIgnorableSentryNoise(Object? error) {
  if (error == null) return false;
  final msg = error.toString();
  return msg.contains(kSentryViewInsetsNoise) ||
      msg.contains(kSentryDebugNeedsLayout) ||
      msg.contains(kSentryTooltipTicker);
}

/// Pure drop policy for unit tests and [filterSentryEvent].
///
/// [debugUploadAllowed] maps to `--dart-define=SENTRY_DEBUG_UPLOAD=true`.
bool shouldDropSentryEvent({
  required String? environment,
  required bool debugUploadAllowed,
  required String haystack,
}) {
  if (environment == 'debug' && !debugUploadAllowed) {
    return true;
  }
  if (haystack.contains(kSentryViewInsetsNoise)) {
    return true;
  }
  if (haystack.contains(kSentryDebugNeedsLayout)) {
    return true;
  }
  if (haystack.contains(kSentryTooltipTicker)) {
    return true;
  }
  if (haystack.contains(kSentryImageViewerLibrary)) {
    return true;
  }
  return false;
}

/// Build a searchable text blob from a [SentryEvent] for noise matching.
String sentryEventHaystack(SentryEvent event) {
  final buf = StringBuffer();
  final message = event.message;
  if (message != null) {
    if (message.formatted.isNotEmpty) {
      buf.writeln(message.formatted);
    }
    final template = message.template;
    if (template != null && template.isNotEmpty) {
      buf.writeln(template);
    }
  }
  final throwable = event.throwable;
  if (throwable != null) {
    buf.writeln(throwable.toString());
  }
  final exceptions = event.exceptions;
  if (exceptions != null) {
    for (final ex in exceptions) {
      if (ex.type != null) buf.writeln(ex.type);
      if (ex.value != null) buf.writeln(ex.value);
      if (ex.module != null) buf.writeln(ex.module);
    }
  }
  final tags = event.tags;
  if (tags != null) {
    for (final e in tags.entries) {
      buf.writeln('${e.key}=${e.value}');
    }
  }
  return buf.toString();
}

/// [SentryOptions.beforeSend] implementation.
SentryEvent? filterSentryEvent(
  SentryEvent event,
  Hint hint, {
  required bool debugUploadAllowed,
}) {
  final drop = shouldDropSentryEvent(
    environment: event.environment,
    debugUploadAllowed: debugUploadAllowed,
    haystack: sentryEventHaystack(event),
  );
  return drop ? null : event;
}
