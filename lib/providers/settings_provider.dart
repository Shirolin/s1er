import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_local_data.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.themeColor = 'purple',
    this.showImages = true,
    this.recordReadingHistory = true,
    this.fontSize = S1Typography.defaultBodySize,
    this.useDynamicColor = false,
    this.collapsedForums = const {},
    this.simulateDynamic = false,
  });

  final String themeMode;
  final String themeColor;
  final bool showImages;
  final bool recordReadingHistory;
  final int fontSize;
  final bool useDynamicColor;
  final Set<String> collapsedForums;
  final bool simulateDynamic;

  double get textScaleFactor => fontSize / S1Typography.defaultBodySize;

  AppSettings copyWith({
    String? themeMode,
    String? themeColor,
    bool? showImages,
    bool? recordReadingHistory,
    int? fontSize,
    bool? useDynamicColor,
    Set<String>? collapsedForums,
    bool? simulateDynamic,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      showImages: showImages ?? this.showImages,
      recordReadingHistory:
          recordReadingHistory ?? this.recordReadingHistory,
      fontSize: fontSize ?? this.fontSize,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      collapsedForums: collapsedForums ?? this.collapsedForums,
      simulateDynamic: simulateDynamic ?? this.simulateDynamic,
    );
  }
}

final localDataProvider = Provider<AppLocalData>((ref) {
  throw StateError('AppLocalData not initialized');
});

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return ref.watch(localDataProvider).settings;
});

class SettingsNotifier extends Notifier<AppSettings> {
  SettingsNotifier({this.initial, this.store});

  final AppSettings? initial;
  final SettingsStore? store;

  @override
  AppSettings build() {
    if (initial != null) return initial!;
    return _loadSettings();
  }

  SettingsStore? get _effectiveStore {
    if (store != null) return store;
    try {
      return ref.read(settingsStoreProvider);
    } catch (_) {
      return null;
    }
  }

  void _persist(String key, Object? value) => _effectiveStore?.put(key, value);

  AppSettings _loadSettings() {
    final settingsStore = _effectiveStore;
    if (settingsStore == null) return const AppSettings();

    String themeMode =
        settingsStore.get<String>('themeMode', defaultValue: '') ?? '';
    if (themeMode.isEmpty) {
      final oldDarkMode =
          settingsStore.get<bool>('darkMode', defaultValue: false) ?? false;
      themeMode = oldDarkMode ? 'dark' : 'system';
      settingsStore.put('themeMode', themeMode);
    }

    return AppSettings(
      themeMode: themeMode,
      themeColor: settingsStore.get<String>('themeColor', defaultValue: 'purple') ??
          'purple',
      showImages:
          settingsStore.get<bool>('showImages', defaultValue: true) ?? true,
      recordReadingHistory: settingsStore.get<bool>(
            'recordReadingHistory',
            defaultValue: true,
          ) ??
          true,
      fontSize: settingsStore.get<int>(
            'fontSize',
            defaultValue: S1Typography.defaultBodySize,
          ) ??
          S1Typography.defaultBodySize,
      useDynamicColor: settingsStore.get<bool>(
            'useDynamicColor',
            defaultValue: false,
          ) ??
          false,
      collapsedForums: Set<String>.from(
        (settingsStore.get<List<dynamic>>('collapsedForums'))?.cast<String>() ??
            [],
      ),
      simulateDynamic: settingsStore.get<bool>(
            'simulateDynamic',
            defaultValue: false,
          ) ??
          false,
    );
  }

  void setThemeMode(String value) {
    state = state.copyWith(themeMode: value);
    _persist('themeMode', value);
  }

  void setThemeColor(String value) {
    state = state.copyWith(themeColor: value);
    _persist('themeColor', value);
  }

  void setShowImages(bool value) {
    state = state.copyWith(showImages: value);
    _persist('showImages', value);
  }

  void setRecordReadingHistory(bool value) {
    state = state.copyWith(recordReadingHistory: value);
    _persist('recordReadingHistory', value);
  }

  void setFontSize(int value) {
    state = state.copyWith(fontSize: value);
    _persist('fontSize', value);
  }

  void setUseDynamicColor(bool value) {
    state = state.copyWith(useDynamicColor: value);
    _persist('useDynamicColor', value);
  }

  void setSimulateDynamic(bool value) {
    state = state.copyWith(simulateDynamic: value);
    _persist('simulateDynamic', value);
  }

  void toggleForumCollapse(String fid) {
    final collapsed = Set<String>.from(state.collapsedForums);
    if (collapsed.contains(fid)) {
      collapsed.remove(fid);
    } else {
      collapsed.add(fid);
    }
    state = state.copyWith(collapsedForums: collapsed);
    _persist('collapsedForums', collapsed.toList());
  }

  void resetAppearanceSettings() {
    const defaults = AppSettings();
    state = state.copyWith(
      themeMode: defaults.themeMode,
      themeColor: defaults.themeColor,
      showImages: defaults.showImages,
      recordReadingHistory: defaults.recordReadingHistory,
      fontSize: defaults.fontSize,
      useDynamicColor: defaults.useDynamicColor,
      simulateDynamic: defaults.simulateDynamic,
    );
    _persist('themeMode', defaults.themeMode);
    _persist('themeColor', defaults.themeColor);
    _persist('showImages', defaults.showImages);
    _persist('recordReadingHistory', defaults.recordReadingHistory);
    _persist('fontSize', defaults.fontSize);
    _persist('useDynamicColor', defaults.useDynamicColor);
    _persist('simulateDynamic', defaults.simulateDynamic);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class DynamicColorAvailable extends Notifier<bool> {
  @override
  bool build() => false;

  void setAvailable(bool value) => state = value;
}

final dynamicColorAvailableProvider =
    NotifierProvider<DynamicColorAvailable, bool>(DynamicColorAvailable.new);
