import 'dart:developer' show log;

import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../config/env_config.dart';

/// Default console output for Flutter:
/// - Web: `print`
/// - iOS / macOS: `dart:developer.log`
/// - Other: `debugPrint`
void _defaultFlutterOutput(String message) {
  if (kIsWeb) {
    // ignore: avoid_print
    print(message);
    return;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      log(message, name: 'Talker');
      break;
    default:
      debugPrint(message);
  }
}

final talker = Talker(
  logger: TalkerLogger(output: _defaultFlutterOutput),
  settings: TalkerSettings(
    enabled: EnvConfig.talkerEnabled,
    useHistory: true,
    maxHistoryItems: EnvConfig.talkerMaxHistory,
  ),
);
