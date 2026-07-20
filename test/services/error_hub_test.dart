import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  late void Function(FlutterErrorDetails)? savedFlutterHandler;
  late bool Function(Object, StackTrace)? savedPlatformHandler;

  setUp(() {
    savedFlutterHandler = FlutterError.onError;
    savedPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = savedFlutterHandler;
    PlatformDispatcher.instance.onError = savedPlatformHandler;
  });

  group('Talker() constructor does not install global hooks', () {
    test('FlutterError.onError is unchanged after creating Talker', () {
      final before = FlutterError.onError;
      Talker(settings: TalkerSettings(enabled: true, useHistory: true));
      expect(FlutterError.onError, same(before));
    });

    test('PlatformDispatcher.onError is unchanged after creating Talker', () {
      final before = PlatformDispatcher.instance.onError;
      Talker(settings: TalkerSettings(enabled: true, useHistory: true));
      expect(PlatformDispatcher.instance.onError, same(before));
    });
  });

  group('_setupErrorHub pattern — FlutterError forwarding', () {
    test('talker.history receives error after forwarding handler is installed',
        () {
      final talker = Talker(
        settings: TalkerSettings(enabled: true, useHistory: true),
      );

      final prevOnError = FlutterError.onError;
      void flutterHandler(FlutterErrorDetails details) {
        talker.handle(details.exception, details.stack, 'FlutterError');
        prevOnError?.call(details);
      }
      FlutterError.onError = flutterHandler;

      final error = Exception('test crash');
      flutterHandler(
        FlutterErrorDetails(exception: error, stack: StackTrace.current),
      );

      expect(talker.history, hasLength(1));
      final entry = talker.history.first;
      expect(entry.exception, same(error));
      expect(entry.message, 'FlutterError');
      expect(entry.title, 'exception');
    });

    test('previous FlutterError handler is still invoked (chain)', () {
      final talker = Talker(
        settings: TalkerSettings(enabled: true, useHistory: true),
      );

      var previousCalled = false;
      FlutterErrorDetails? capturedDetails;
      final stashed = FlutterError.onError;
      void middleHandler(FlutterErrorDetails details) {
        previousCalled = true;
        capturedDetails = details;
        stashed?.call(details);
      }
      FlutterError.onError = middleHandler;

      final prevOnError = FlutterError.onError;
      void hubHandler(FlutterErrorDetails details) {
        talker.handle(details.exception, details.stack, 'FlutterError');
        prevOnError?.call(details);
      }

      final error = Exception('chained');
      hubHandler(
        FlutterErrorDetails(exception: error, stack: StackTrace.current),
      );

      expect(previousCalled, isTrue);
      expect(capturedDetails!.exception, same(error));
      expect(talker.history, hasLength(1));
      expect(talker.history.first.exception, same(error));
    });
  });

  group('_setupErrorHub pattern — PlatformDispatcher forwarding', () {
    test(
        'talker.history receives error after PlatformDispatcher handler is installed',
        () {
      final talker = Talker(
        settings: TalkerSettings(enabled: true, useHistory: true),
      );

      final prevPlatformError = PlatformDispatcher.instance.onError;
      bool platformHandler(Object error, StackTrace stack) {
        talker.handle(error, stack, 'PlatformDispatcher');
        return prevPlatformError?.call(error, stack) ?? true;
      }
      PlatformDispatcher.instance.onError = platformHandler;

      final err = StateError('platform crash');
      final stack = StackTrace.current;
      platformHandler(err, stack);

      expect(talker.history, hasLength(1));
      final entry = talker.history.first;
      expect(entry.error, same(err));
      expect(entry.exception, isNull);
      expect(entry.message, 'PlatformDispatcher');
      expect(entry.title, 'error');
    });

    test('previous PlatformDispatcher handler is still invoked (chain)', () {
      final talker = Talker(
        settings: TalkerSettings(enabled: true, useHistory: true),
      );

      var previousCalled = false;
      var previousResult = false;
      final stashed = PlatformDispatcher.instance.onError;
      bool middleHandler(Object error, StackTrace stack) {
        previousCalled = true;
        previousResult = stashed?.call(error, stack) ?? true;
        return true;
      }
      PlatformDispatcher.instance.onError = middleHandler;

      final prevPlatformError = PlatformDispatcher.instance.onError;
      bool hubHandler(Object error, StackTrace stack) {
        talker.handle(error, stack, 'PlatformDispatcher');
        return prevPlatformError?.call(error, stack) ?? true;
      }

      final err = StateError('chained platform');
      hubHandler(err, StackTrace.current);

      expect(previousCalled, isTrue);
      expect(previousResult, isTrue);
      expect(talker.history, hasLength(1));
      expect(talker.history.first.error, same(err));
    });
  });
}
