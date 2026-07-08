import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: true,
    useHistory: true,
    maxHistoryItems: 500,
  ),
);
