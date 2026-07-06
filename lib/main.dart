import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'models/emoticon.dart';
import 'services/http_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  // Initialize HTTP client
  await S1HttpClient.instance.init();

  // Initialize emoticon map
  EmoticonMap.initialize();

  runApp(
    const ProviderScope(
      child: S1App(),
    ),
  );
}
