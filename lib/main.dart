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

  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  final container = ProviderContainer();
  final httpClient = container.read(httpClientProvider);
  await httpClient.init();
  httpClient.dio.interceptors.add(
    TalkerDioLogger(talker: talker),
  );

  EmoticonMap.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const S1App(),
    ),
  );
}
