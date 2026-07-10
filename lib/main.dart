import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'app.dart';
import 'models/emoticon.dart';
import 'services/http_client.dart';
import 'services/talker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is AssertionError &&
          exception.message.toString().contains('ViewInsets cannot be negative')) {
        return;
      }
      if (originalOnError != null) {
        originalOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is AssertionError &&
          error.message.toString().contains('ViewInsets cannot be negative')) {
        return true;
      }
      return false;
    };
  }

  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');
  await Hive.openBox<Map>('reading_history');

  final container = ProviderContainer();
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
        requestFilter: (_) => false,
        responseFilter: (_) => false,
      ),
    ),
  );

  EmoticonMap.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const S1App(),
    ),
  );
}
