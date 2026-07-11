import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../theme/app_theme.dart';

class AppSettings {
  AppSettings({
    this.themeMode = 'system',
    this.themeColor = 'purple',
    this.showImages = true,
    this.fontSize = S1Typography.defaultBodySize,
    this.useDynamicColor = false,
    this.collapsedForums = const {},
  });

  final String themeMode;
  final String themeColor;
  final bool showImages;
  final int fontSize;
  final bool useDynamicColor;
  final Set<String> collapsedForums;

  double get textScaleFactor => fontSize / S1Typography.defaultBodySize;

  AppSettings copyWith({
    String? themeMode,
    String? themeColor,
    bool? showImages,
    int? fontSize,
    bool? useDynamicColor,
    Set<String>? collapsedForums,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      showImages: showImages ?? this.showImages,
      fontSize: fontSize ?? this.fontSize,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      collapsedForums: collapsedForums ?? this.collapsedForums,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier([AppSettings? initial]) : super(initial ?? AppSettings()) {
    if (initial == null) {
      _loadSettings();
    }
  }

  void _loadSettings() {
    final box = Hive.box('settings');

    String themeMode = box.get('themeMode', defaultValue: '') as String;
    if (themeMode.isEmpty) {
      final oldDarkMode = box.get('darkMode', defaultValue: false) as bool;
      themeMode = oldDarkMode ? 'dark' : 'system';
      box.put('themeMode', themeMode);
    }

    state = AppSettings(
      themeMode: themeMode,
      themeColor: box.get('themeColor', defaultValue: 'purple') as String,
      showImages: box.get('showImages', defaultValue: true),
      fontSize: box.get('fontSize', defaultValue: S1Typography.defaultBodySize),
      useDynamicColor: box.get('useDynamicColor', defaultValue: false),
      collapsedForums: Set<String>.from(
        (box.get('collapsedForums') as List?)?.cast<String>() ?? [],
      ),
    );
  }

  void setThemeMode(String value) {
    state = state.copyWith(themeMode: value);
    Hive.box('settings').put('themeMode', value);
  }

  void setThemeColor(String value) {
    state = state.copyWith(themeColor: value);
    Hive.box('settings').put('themeColor', value);
  }

  void setShowImages(bool value) {
    state = state.copyWith(showImages: value);
    Hive.box('settings').put('showImages', value);
  }

  void setFontSize(int value) {
    state = state.copyWith(fontSize: value);
    Hive.box('settings').put('fontSize', value);
  }

  void setUseDynamicColor(bool value) {
    state = state.copyWith(useDynamicColor: value);
    Hive.box('settings').put('useDynamicColor', value);
  }

  void toggleForumCollapse(String fid) {
    final collapsed = Set<String>.from(state.collapsedForums);
    if (collapsed.contains(fid)) {
      collapsed.remove(fid);
    } else {
      collapsed.add(fid);
    }
    state = state.copyWith(collapsedForums: collapsed);
    Hive.box('settings').put('collapsedForums', collapsed.toList());
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
