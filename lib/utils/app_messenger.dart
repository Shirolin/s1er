import 'package:flutter/material.dart';

/// Root messenger key so non-widget code (tray callbacks) can show a SnackBar
/// without a `BuildContext`.
final GlobalKey<ScaffoldMessengerState> s1MessengerKey =
    GlobalKey<ScaffoldMessengerState>();
