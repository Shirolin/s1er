import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'app.dart';
import 'models/emoticon.dart';
import 'providers/talker_provider.dart';
import 'services/http_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  final talker = TalkerFlutter.init(
    settings: TalkerSettings(
      enabled: true,
      useHistory: true,
      maxHistoryItems: 500,
    ),
  );

  final container = ProviderContainer();
  // Override the talkerProvider with the instance created above
  container.read(talkerProvider.notifier).state = talker;

  final httpClient = container.read(httpClientProvider);
  await httpClient.init();
  httpClient.dio.interceptors.add(
    TalkerDioLogger(talker: talker),
  );

  EmoticonMap.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: S1App(talker: talker),
    ),
  );
}
