import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_icon_catalog.dart';
import '../models/image_load_policy.dart';
import '../models/list_density.dart';
import '../models/share_image_format.dart';
import '../models/share_pixel_ratio.dart';
import '../config/constants.dart';
import '../services/app_icon_service.dart';
import '../services/app_local_data.dart';
import '../services/font_import_service.dart';
import '../services/s1_image_cache.dart';
import '../services/settings_store.dart';
import '../services/talker.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.themeColor = AppTheme.defaultThemeColorKey,
    this.appIcon = AppIconCatalog.defaultId,
    this.showImages = true,
    this.imageLoadPolicy = ImageLoadPolicy.always,
    this.avatarLoadPolicy = ImageLoadPolicy.always,
    this.maxImagesPerPost = S1Constants.defaultMaxImagesPerPost,
    this.imageCacheLimitMb = S1Constants.defaultImageCacheLimitMb,
    this.recordReadingHistory = true,
    this.hapticsEnabled = true,
    this.threadListDensity = ListDensity.standard,
    this.postListDensity = ListDensity.standard,
    this.fontSize = S1Typography.defaultBodySize,
    this.collapsedForums = const {},
    this.shareImageFormat = ShareImageFormat.webp,
    this.sharePixelRatio = SharePixelRatio.defaultValue,
    this.postSignatureEnabled = true,
    this.postSignatureShowDevice = true,
    this.postSignatureCustom = '',
    this.customFontFileName,
  });

  final String themeMode;
  final String themeColor;
  final String appIcon;
  final bool showImages;
  final ImageLoadPolicy imageLoadPolicy;
  final ImageLoadPolicy avatarLoadPolicy;
  final int maxImagesPerPost;
  final int imageCacheLimitMb;
  final bool recordReadingHistory;
  final bool hapticsEnabled;
  final ListDensity threadListDensity;
  final ListDensity postListDensity;
  final int fontSize;
  final Set<String> collapsedForums;
  final ShareImageFormat shareImageFormat;
  final double sharePixelRatio;
  final bool postSignatureEnabled;
  final bool postSignatureShowDevice;
  final String postSignatureCustom;
  final String? customFontFileName;

  double get textScaleFactor => fontSize / S1Typography.defaultBodySize;

  AppSettings copyWith({
    String? themeMode,
    String? themeColor,
    String? appIcon,
    bool? showImages,
    ImageLoadPolicy? imageLoadPolicy,
    ImageLoadPolicy? avatarLoadPolicy,
    int? maxImagesPerPost,
    int? imageCacheLimitMb,
    bool? recordReadingHistory,
    bool? hapticsEnabled,
    ListDensity? threadListDensity,
    ListDensity? postListDensity,
    int? fontSize,
    Set<String>? collapsedForums,
    ShareImageFormat? shareImageFormat,
    double? sharePixelRatio,
    bool? postSignatureEnabled,
    bool? postSignatureShowDevice,
    String? postSignatureCustom,
    Object? customFontFileName = _Sentinel.value,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      appIcon: appIcon ?? this.appIcon,
      showImages: showImages ?? this.showImages,
      imageLoadPolicy: imageLoadPolicy ?? this.imageLoadPolicy,
      avatarLoadPolicy: avatarLoadPolicy ?? this.avatarLoadPolicy,
      maxImagesPerPost: maxImagesPerPost ?? this.maxImagesPerPost,
      imageCacheLimitMb: imageCacheLimitMb ?? this.imageCacheLimitMb,
      recordReadingHistory: recordReadingHistory ?? this.recordReadingHistory,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      threadListDensity: threadListDensity ?? this.threadListDensity,
      postListDensity: postListDensity ?? this.postListDensity,
      fontSize: fontSize ?? this.fontSize,
      collapsedForums: collapsedForums ?? this.collapsedForums,
      shareImageFormat: shareImageFormat ?? this.shareImageFormat,
      sharePixelRatio: sharePixelRatio ?? this.sharePixelRatio,
      postSignatureEnabled: postSignatureEnabled ?? this.postSignatureEnabled,
      postSignatureShowDevice:
          postSignatureShowDevice ?? this.postSignatureShowDevice,
      postSignatureCustom: postSignatureCustom ?? this.postSignatureCustom,
      customFontFileName: customFontFileName == _Sentinel.value
          ? this.customFontFileName
          : customFontFileName as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.themeColor == themeColor &&
        other.appIcon == appIcon &&
        other.showImages == showImages &&
        other.imageLoadPolicy == imageLoadPolicy &&
        other.avatarLoadPolicy == avatarLoadPolicy &&
        other.maxImagesPerPost == maxImagesPerPost &&
        other.imageCacheLimitMb == imageCacheLimitMb &&
        other.recordReadingHistory == recordReadingHistory &&
        other.hapticsEnabled == hapticsEnabled &&
        other.threadListDensity == threadListDensity &&
        other.postListDensity == postListDensity &&
        other.fontSize == fontSize &&
        _setEquals(other.collapsedForums, collapsedForums) &&
        other.shareImageFormat == shareImageFormat &&
        other.sharePixelRatio == sharePixelRatio &&
        other.postSignatureEnabled == postSignatureEnabled &&
        other.postSignatureShowDevice == postSignatureShowDevice &&
        other.postSignatureCustom == postSignatureCustom &&
        other.customFontFileName == customFontFileName;
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
        themeMode,
        themeColor,
        appIcon,
        showImages,
        imageLoadPolicy,
        avatarLoadPolicy,
        maxImagesPerPost,
        imageCacheLimitMb,
        recordReadingHistory,
        hapticsEnabled,
        threadListDensity,
        postListDensity,
        fontSize,
        Object.hashAllUnordered(collapsedForums),
        shareImageFormat,
        sharePixelRatio,
        Object.hash(
          postSignatureEnabled,
          postSignatureShowDevice,
          postSignatureCustom,
          customFontFileName,
        ),
      );
}

class _Sentinel {
  const _Sentinel();
  static const value = _Sentinel();
}

final localDataProvider = Provider<AppLocalData>((ref) {
  throw StateError('AppLocalData not initialized');
});

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return ref.watch(localDataProvider).settings;
});

final appIconServiceProvider = Provider<AppIconService>((ref) {
  return AppIconService.instance;
});

final fontImportServiceProvider = Provider<Type>((ref) {
  return FontImportService;
});

class SettingsNotifier extends Notifier<AppSettings> {
  SettingsNotifier({this.initial, this.store, this.appIconService});

  final AppSettings? initial;
  final SettingsStore? store;
  final AppIconService? appIconService;

  @override
  AppSettings build() {
    if (initial != null) {
      _applyImageCacheLimit(initial!.imageCacheLimitMb);
      _syncHaptics(initial!.hapticsEnabled);
      if (initial!.customFontFileName != null) {
        unawaited(FontImportService.tryRestoreFont());
      }
      return initial!;
    }
    final settings = _loadSettings();
    _applyImageCacheLimit(settings.imageCacheLimitMb);
    _syncHaptics(settings.hapticsEnabled);
    if (settings.customFontFileName != null) {
      unawaited(FontImportService.tryRestoreFont());
    }
    return settings;
  }

  void _applyImageCacheLimit(int limitMb) {
    S1ImageCache.setMaxCacheBytes(limitMb * 1024 * 1024);
  }

  void _syncHaptics(bool value) {
    S1Haptics.enabled = value;
  }

  SettingsStore? get _effectiveStore {
    if (store != null) return store;
    try {
      return ref.read(settingsStoreProvider);
    } on Object {
      return null;
    }
  }

  AppIconService get _appIconService {
    if (appIconService != null) return appIconService!;
    try {
      return ref.read(appIconServiceProvider);
    } on Object {
      return AppIconService.instance;
    }
  }

  void _persist(String key, Object? value) => _effectiveStore?.put(key, value);

  void _commit(AppSettings next) {
    if (next == state) return;
    _syncHaptics(next.hapticsEnabled);
    state = next;
  }

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
    final storedThemeColor = settingsStore.get<String>(
      'themeColor',
      defaultValue: AppTheme.defaultThemeColorKey,
    );
    final themeColor = AppTheme.normalizeThemeColorKey(storedThemeColor);
    if (themeColor != storedThemeColor) {
      settingsStore.put('themeColor', themeColor);
    }
    final storedAppIcon = settingsStore.get<String>(
      'appIcon',
      defaultValue: AppIconCatalog.defaultId,
    );
    final appIcon = AppIconCatalog.normalize(storedAppIcon);
    if (appIcon != storedAppIcon) {
      settingsStore.put('appIcon', appIcon);
    }

    return AppSettings(
      themeMode: themeMode,
      themeColor: themeColor,
      appIcon: appIcon,
      showImages:
          settingsStore.get<bool>('showImages', defaultValue: true) ?? true,
      imageLoadPolicy: ImageLoadPolicy.fromStored(
        settingsStore.get<String>('imageLoadPolicy'),
      ),
      avatarLoadPolicy: ImageLoadPolicy.fromStored(
        settingsStore.get<String>('avatarLoadPolicy'),
      ),
      maxImagesPerPost: settingsStore.get<int>(
            'maxImagesPerPost',
            defaultValue: S1Constants.defaultMaxImagesPerPost,
          ) ??
          S1Constants.defaultMaxImagesPerPost,
      imageCacheLimitMb: settingsStore.get<int>(
            'imageCacheLimitMb',
            defaultValue: S1Constants.defaultImageCacheLimitMb,
          ) ??
          S1Constants.defaultImageCacheLimitMb,
      recordReadingHistory: settingsStore.get<bool>(
            'recordReadingHistory',
            defaultValue: true,
          ) ??
          true,
      hapticsEnabled: settingsStore.get<bool>(
            'hapticsEnabled',
            defaultValue: true,
          ) ??
          true,
      threadListDensity: ListDensity.fromStored(
        settingsStore.get<String>('threadListDensity'),
      ),
      postListDensity: ListDensity.fromStored(
        settingsStore.get<String>('postListDensity'),
      ),
      fontSize: settingsStore.get<int>(
            'fontSize',
            defaultValue: S1Typography.defaultBodySize,
          ) ??
          S1Typography.defaultBodySize,
      shareImageFormat: ShareImageFormat.fromStored(
        settingsStore.get<String>('shareImageFormat'),
      ),
      sharePixelRatio: SharePixelRatio.normalize(
        settingsStore.get<Object>('sharePixelRatio'),
      ),
      collapsedForums: Set<String>.from(
        (settingsStore.get<List<dynamic>>('collapsedForums'))?.cast<String>() ??
            [],
      ),
      postSignatureEnabled: settingsStore.get<bool>(
            'postSignatureEnabled',
            defaultValue: true,
          ) ??
          true,
      postSignatureShowDevice: settingsStore.get<bool>(
            'postSignatureShowDevice',
            defaultValue: true,
          ) ??
          true,
      postSignatureCustom: settingsStore.get<String>(
            'postSignatureCustom',
            defaultValue: '',
          ) ??
          '',
      customFontFileName: settingsStore.get<String>('customFontFileName'),
    );
  }

  Future<String> importCustomFont(XFile file) async {
    final fileName = await FontImportService.importFont(file);
    _commit(state.copyWith(customFontFileName: fileName));
    _persist('customFontFileName', fileName);
    return fileName;
  }

  void setCustomFont(String fileName) {
    _commit(state.copyWith(customFontFileName: fileName));
    _persist('customFontFileName', fileName);
  }

  void removeCustomFont() {
    unawaited(FontImportService.removeCustomFont());
    _commit(state.copyWith(customFontFileName: null));
    _persist('customFontFileName', null);
  }

  void setThemeMode(String value) {
    _commit(state.copyWith(themeMode: value));
    _persist('themeMode', value);
  }

  void setThemeColor(String value) {
    final themeColor = AppTheme.normalizeThemeColorKey(value);
    _commit(state.copyWith(themeColor: themeColor));
    _persist('themeColor', themeColor);
  }

  /// Persists and applies launcher icon. Returns false on native failure.
  Future<bool> setAppIcon(String value) async {
    final id = AppIconCatalog.normalize(value);
    if (id == state.appIcon) {
      await syncAppIconWithNative();
      return true;
    }
    final previous = state.appIcon;
    _commit(state.copyWith(appIcon: id));
    _persist('appIcon', id);
    try {
      await _appIconService.setIcon(id);
      return true;
    } on Object catch (e, st) {
      talker.handle(e, st, 'setAppIcon($id) failed; rolling back');
      _commit(state.copyWith(appIcon: previous));
      _persist('appIcon', previous);
      return false;
    }
  }

  /// Aligns native launcher icon with persisted setting (e.g. after backup).
  Future<void> syncAppIconWithNative() async {
    final service = _appIconService;
    if (!service.isSupported) return;
    final desired = AppIconCatalog.normalize(state.appIcon);
    try {
      final current = await service.getCurrentIconId();
      if (current == desired) return;
      await service.setIcon(desired);
    } on Object catch (e, st) {
      talker.handle(e, st, 'syncAppIconWithNative($desired) skipped');
    }
  }

  void setShowImages(bool value) {
    _commit(state.copyWith(showImages: value));
    _persist('showImages', value);
  }

  void setImageLoadPolicy(ImageLoadPolicy value) {
    _commit(state.copyWith(imageLoadPolicy: value));
    _persist('imageLoadPolicy', value.storageKey);
  }

  void setAvatarLoadPolicy(ImageLoadPolicy value) {
    _commit(state.copyWith(avatarLoadPolicy: value));
    _persist('avatarLoadPolicy', value.storageKey);
  }

  void setMaxImagesPerPost(int value) {
    _commit(state.copyWith(maxImagesPerPost: value));
    _persist('maxImagesPerPost', value);
  }

  void setImageCacheLimitMb(int value) {
    _commit(state.copyWith(imageCacheLimitMb: value));
    _persist('imageCacheLimitMb', value);
    _applyImageCacheLimit(value);
    S1ImageCache.evictIfNeeded();
  }

  void setRecordReadingHistory(bool value) {
    _commit(state.copyWith(recordReadingHistory: value));
    _persist('recordReadingHistory', value);
  }

  void setHapticsEnabled(bool value) {
    _commit(state.copyWith(hapticsEnabled: value));
    _persist('hapticsEnabled', value);
  }

  void setThreadListDensity(ListDensity value) {
    _commit(state.copyWith(threadListDensity: value));
    _persist('threadListDensity', value.storageKey);
  }

  void setPostListDensity(ListDensity value) {
    _commit(state.copyWith(postListDensity: value));
    _persist('postListDensity', value.storageKey);
  }

  void setFontSize(int value) {
    _commit(state.copyWith(fontSize: value));
    _persist('fontSize', value);
  }

  void setShareImageFormat(ShareImageFormat value) {
    _commit(state.copyWith(shareImageFormat: value));
    _persist('shareImageFormat', value.storageKey);
  }

  void setSharePixelRatio(double value) {
    final snapped = SharePixelRatio.normalize(value);
    _commit(state.copyWith(sharePixelRatio: snapped));
    _persist('sharePixelRatio', snapped);
  }

  void setPostSignatureEnabled(bool value) {
    _commit(state.copyWith(postSignatureEnabled: value));
    _persist('postSignatureEnabled', value);
  }

  void setPostSignatureShowDevice(bool value) {
    _commit(state.copyWith(postSignatureShowDevice: value));
    _persist('postSignatureShowDevice', value);
  }

  void setPostSignatureCustom(String value) {
    _commit(state.copyWith(postSignatureCustom: value));
    _persist('postSignatureCustom', value);
  }

  void toggleForumCollapse(String fid) {
    final collapsed = Set<String>.from(state.collapsedForums);
    if (collapsed.contains(fid)) {
      collapsed.remove(fid);
    } else {
      collapsed.add(fid);
    }
    _commit(state.copyWith(collapsedForums: collapsed));
    _persist('collapsedForums', collapsed.toList());
  }

  void resetAppearanceSettings() {
    const defaults = AppSettings();
    final next = state.copyWith(
      themeMode: defaults.themeMode,
      themeColor: defaults.themeColor,
      appIcon: defaults.appIcon,
      showImages: defaults.showImages,
      imageLoadPolicy: defaults.imageLoadPolicy,
      avatarLoadPolicy: defaults.avatarLoadPolicy,
      maxImagesPerPost: defaults.maxImagesPerPost,
      imageCacheLimitMb: defaults.imageCacheLimitMb,
      recordReadingHistory: defaults.recordReadingHistory,
      hapticsEnabled: defaults.hapticsEnabled,
      threadListDensity: defaults.threadListDensity,
      postListDensity: defaults.postListDensity,
      fontSize: defaults.fontSize,
      shareImageFormat: defaults.shareImageFormat,
      sharePixelRatio: defaults.sharePixelRatio,
      customFontFileName: null,
    );
    _commit(next);
    unawaited(FontImportService.removeCustomFont());
    _persist('themeMode', defaults.themeMode);
    _persist('themeColor', defaults.themeColor);
    _persist('appIcon', defaults.appIcon);
    _persist('showImages', defaults.showImages);
    _persist('imageLoadPolicy', defaults.imageLoadPolicy.storageKey);
    _persist('avatarLoadPolicy', defaults.avatarLoadPolicy.storageKey);
    _persist('maxImagesPerPost', defaults.maxImagesPerPost);
    _persist('imageCacheLimitMb', defaults.imageCacheLimitMb);
    _applyImageCacheLimit(defaults.imageCacheLimitMb);
    _persist('recordReadingHistory', defaults.recordReadingHistory);
    _persist('hapticsEnabled', defaults.hapticsEnabled);
    _persist('threadListDensity', defaults.threadListDensity.storageKey);
    _persist('postListDensity', defaults.postListDensity.storageKey);
    _persist('fontSize', defaults.fontSize);
    _persist('shareImageFormat', defaults.shareImageFormat.storageKey);
    _persist('sharePixelRatio', defaults.sharePixelRatio);
    _persist('customFontFileName', null);
    // Best-effort native align; failures are logged inside sync.
    // ignore: discarded_futures
    syncAppIconWithNative();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
