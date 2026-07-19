import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:s1er/services/sentry_event_filter.dart';

void main() {
  group('isIgnorableSentryNoise', () {
    test('matches ViewInsets assertion text', () {
      expect(
        isIgnorableSentryNoise(
          AssertionError('ViewInsets cannot be negative'),
        ),
        isTrue,
      );
    });

    test('ignores unrelated errors', () {
      expect(isIgnorableSentryNoise(StateError('boom')), isFalse);
      expect(isIgnorableSentryNoise(null), isFalse);
    });
  });

  group('shouldDropSentryEvent', () {
    test('drops debug unless upload allowed', () {
      expect(
        shouldDropSentryEvent(
          environment: 'debug',
          debugUploadAllowed: false,
          haystack: 'StateError: boom',
        ),
        isTrue,
      );
      expect(
        shouldDropSentryEvent(
          environment: 'debug',
          debugUploadAllowed: true,
          haystack: 'StateError: boom',
        ),
        isFalse,
      );
    });

    test('keeps production crashes', () {
      expect(
        shouldDropSentryEvent(
          environment: 'production',
          debugUploadAllowed: false,
          haystack: 'StateError: boom',
        ),
        isFalse,
      );
    });

    test('drops ViewInsets and image_viewer markers', () {
      expect(
        shouldDropSentryEvent(
          environment: 'production',
          debugUploadAllowed: false,
          haystack: 'AssertionError: $kSentryViewInsetsNoise',
        ),
        isTrue,
      );
      expect(
        shouldDropSentryEvent(
          environment: 'production',
          debugUploadAllowed: false,
          haystack: 'library=$kSentryImageViewerLibrary',
        ),
        isTrue,
      );
    });
  });

  group('filterSentryEvent', () {
    test('returns null for debug without upload flag', () {
      final event = SentryEvent(
        environment: 'debug',
        throwable: StateError('boom'),
      );
      expect(
        filterSentryEvent(
          event,
          Hint(),
          debugUploadAllowed: false,
        ),
        isNull,
      );
    });

    test('returns event for production crash', () {
      final event = SentryEvent(
        environment: 'production',
        throwable: StateError('boom'),
      );
      expect(
        filterSentryEvent(
          event,
          Hint(),
          debugUploadAllowed: false,
        ),
        same(event),
      );
    });

    test('drops ViewInsets via haystack from throwable', () {
      final event = SentryEvent(
        environment: 'production',
        throwable: AssertionError(kSentryViewInsetsNoise),
      );
      expect(
        filterSentryEvent(
          event,
          Hint(),
          debugUploadAllowed: true,
        ),
        isNull,
      );
    });
  });
}
