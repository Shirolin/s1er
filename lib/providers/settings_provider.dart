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

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier({SettingsStore? store, AppSettings? initial})
      : _store = store,
        super(initial ?? const AppSettings()) {
    if (initial == null) {
      _loadSettings();
    }
  }

  final SettingsStore? _store;

  void _persist(String key, Object? value) => _store?.put(key, value);

  void _loadSettings() {
    final store = _store;
    if (store == null) return;

    String themeMode = store.get<String>('themeMode', defaultValue: '') ?? '';
    if (themeMode.isEmpty) {
      final oldDarkMode =
          store.get<bool>('darkMode', defaultValue: false) ?? false;
      themeMode = oldDarkMode ? 'dark' : 'system';
      store.put('themeMode', themeMode);
    }

    state = AppSettings(
      themeMode: themeMode,
      themeColor:
          store.get<String>('themeColor', defaultValue: 'purple') ?? 'purple',
      showImages: store.get<bool>('showImages', defaultValue: true) ?? true,
      recordReadingHistory:
          store.get<bool>('recordReadingHistory', defaultValue: true) ?? true,
      fontSize: store.get<int>(
            'fontSize',
            defaultValue: S1Typography.defaultBodySize,
          ) ??
          S1Typography.defaultBodySize,
      useDynamicColor:
          store.get<bool>('useDynamicColor', defaultValue: false) ?? false,
      collapsedForums: Set<String>.from(
        (store.get<List<dynamic>>('collapsedForums'))?.cast<String>() ?? [],
      ),
      simulateDynamic:
          store.get<bool>('simulateDynamic', defaultValue: false) ?? false,
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
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(store: ref.watch(settingsStoreProvider));
});

final dynamicColorAvailableProvider = StateProvider<bool>((ref) => false);
