import 'package:talker_flutter/talker_flutter.dart';
import '../config/env_config.dart';

final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: EnvConfig.talkerEnabled,
    useHistory: true,
    maxHistoryItems: EnvConfig.talkerMaxHistory,
  ),
);
