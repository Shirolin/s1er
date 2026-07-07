import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class AppSettings {

  AppSettings({
    this.themeMode = 'system',
    this.showImages = true,
    this.fontSize = 14,
    this.collapsedForums = const {},
  });
  final String themeMode;
  final bool showImages;
  final int fontSize;
  final Set<String> collapsedForums;

  AppSettings copyWith({
    String? themeMode,
    bool? showImages,
    int? fontSize,
    Set<String>? collapsedForums,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      showImages: showImages ?? this.showImages,
      fontSize: fontSize ?? this.fontSize,
      collapsedForums: collapsedForums ?? this.collapsedForums,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
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
      showImages: box.get('showImages', defaultValue: true),
      fontSize: box.get('fontSize', defaultValue: 14),
      collapsedForums: Set<String>.from(
        (box.get('collapsedForums') as List?)?.cast<String>() ?? [],
      ),
    );
  }

  void setThemeMode(String value) {
    state = state.copyWith(themeMode: value);
    Hive.box('settings').put('themeMode', value);
  }

  void setShowImages(bool value) {
    state = state.copyWith(showImages: value);
    Hive.box('settings').put('showImages', value);
  }

  void setFontSize(int value) {
    state = state.copyWith(fontSize: value);
    Hive.box('settings').put('fontSize', value);
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
