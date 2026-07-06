import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class AppSettings {
  final bool darkMode;
  final bool showImages;
  final int fontSize;

  AppSettings({
    this.darkMode = false,
    this.showImages = true,
    this.fontSize = 14,
  });

  AppSettings copyWith({bool? darkMode, bool? showImages, int? fontSize}) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      showImages: showImages ?? this.showImages,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final box = Hive.box('settings');
    state = AppSettings(
      darkMode: box.get('darkMode', defaultValue: false),
      showImages: box.get('showImages', defaultValue: true),
      fontSize: box.get('fontSize', defaultValue: 14),
    );
  }

  void setDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
    Hive.box('settings').put('darkMode', value);
  }

  void setShowImages(bool value) {
    state = state.copyWith(showImages: value);
    Hive.box('settings').put('showImages', value);
  }

  void setFontSize(int value) {
    state = state.copyWith(fontSize: value);
    Hive.box('settings').put('fontSize', value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
