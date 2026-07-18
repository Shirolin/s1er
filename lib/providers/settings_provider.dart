import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/image_load_policy.dart';
import '../models/share_image_format.dart';
import '../models/share_pixel_ratio.dart';
import '../config/constants.dart';
import '../services/app_local_data.dart';
import '../services/s1_image_cache.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.themeColor = AppTheme.defaultThemeColorKey,
    this.showImages = true,
    this.imageLoadPolicy = ImageLoadPolicy.always,
    this.avatarLoadPolicy = ImageLoadPolicy.always,
    this.maxImagesPerPost = S1Constants.defaultMaxImagesPerPost,
    this.imageCacheLimitMb = S1Constants.defaultImageCacheLimitMb,
    this.recordReadingHistory = true,
    this.fontSize = S1Typography.defaultBodySize,
    this.collapsedForums = const {},
    this.shareImageFormat = ShareImageFormat.webp,
    this.sharePixelRatio = SharePixelRatio.defaultValue,
    this.postSignatureEnabled = true,
    this.postSignatureShowDevice = true,
    this.postSignatureCustom = '',
  });

  final String themeMode;
  final String themeColor;
  final bool showImages;
  final ImageLoadPolicy imageLoadPolicy;
  final ImageLoadPolicy avatarLoadPolicy;
  final int maxImagesPerPost;
  final int imageCacheLimitMb;
  final bool recordReadingHistory;
  final int fontSize;
  final Set<String> collapsedForums;
  final ShareImageFormat shareImageFormat;
  final double sharePixelRatio;
  final bool postSignatureEnabled;
  final bool postSignatureShowDevice;
  final String postSignatureCustom;

  double get textScaleFactor => fontSize / S1Typography.defaultBodySize;

  AppSettings copyWith({
    String? themeMode,
    String? themeColor,
    bool? showImages,
    ImageLoadPolicy? imageLoadPolicy,
    ImageLoadPolicy? avatarLoadPolicy,
    int? maxImagesPerPost,
    int? imageCacheLimitMb,
    bool? recordReadingHistory,
    int? fontSize,
    Set<String>? collapsedForums,
    ShareImageFormat? shareImageFormat,
    double? sharePixelRatio,
    bool? postSignatureEnabled,
    bool? postSignatureShowDevice,
    String? postSignatureCustom,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      showImages: showImages ?? this.showImages,
      imageLoadPolicy: imageLoadPolicy ?? this.imageLoadPolicy,
      avatarLoadPolicy: avatarLoadPolicy ?? this.avatarLoadPolicy,
      maxImagesPerPost: maxImagesPerPost ?? this.maxImagesPerPost,
      imageCacheLimitMb: imageCacheLimitMb ?? this.imageCacheLimitMb,
      recordReadingHistory: recordReadingHistory ?? this.recordReadingHistory,
      fontSize: fontSize ?? this.fontSize,
      collapsedForums: collapsedForums ?? this.collapsedForums,
      shareImageFormat: shareImageFormat ?? this.shareImageFormat,
      sharePixelRatio: sharePixelRatio ?? this.sharePixelRatio,
      postSignatureEnabled: postSignatureEnabled ?? this.postSignatureEnabled,
      postSignatureShowDevice:
          postSignatureShowDevice ?? this.postSignatureShowDevice,
      postSignatureCustom: postSignatureCustom ?? this.postSignatureCustom,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.themeColor == themeColor &&
        other.showImages == showImages &&
        other.imageLoadPolicy == imageLoadPolicy &&
        other.avatarLoadPolicy == avatarLoadPolicy &&
        other.maxImagesPerPost == maxImagesPerPost &&
        other.imageCacheLimitMb == imageCacheLimitMb &&
        other.recordReadingHistory == recordReadingHistory &&
        other.fontSize == fontSize &&
        _setEquals(other.collapsedForums, collapsedForums) &&
        other.shareImageFormat == shareImageFormat &&
        other.sharePixelRatio == sharePixelRatio &&
        other.postSignatureEnabled == postSignatureEnabled &&
        other.postSignatureShowDevice == postSignatureShowDevice &&
        other.postSignatureCustom == postSignatureCustom;
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
        themeMode,
        themeColor,
        showImages,
        imageLoadPolicy,
        avatarLoadPolicy,
        maxImagesPerPost,
        imageCacheLimitMb,
        recordReadingHistory,
        fontSize,
        Object.hashAllUnordered(collapsedForums),
        shareImageFormat,
        sharePixelRatio,
        postSignatureEnabled,
        postSignatureShowDevice,
        postSignatureCustom,
      );
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
    if (initial != null) {
      _applyImageCacheLimit(initial!.imageCacheLimitMb);
      return initial!;
    }
    final settings = _loadSettings();
    _applyImageCacheLimit(settings.imageCacheLimitMb);
    return settings;
  }

  void _applyImageCacheLimit(int limitMb) {
    S1ImageCache.setMaxCacheBytes(limitMb * 1024 * 1024);
  }

  SettingsStore? get _effectiveStore {
    if (store != null) return store;
    try {
      return ref.read(settingsStoreProvider);
    } on Object {
      return null;
    }
  }

  void _persist(String key, Object? value) => _effectiveStore?.put(key, value);

  void _commit(AppSettings next) {
    if (next == state) return;
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

    return AppSettings(
      themeMode: themeMode,
      themeColor: themeColor,
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
    );
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
      showImages: defaults.showImages,
      imageLoadPolicy: defaults.imageLoadPolicy,
      avatarLoadPolicy: defaults.avatarLoadPolicy,
      maxImagesPerPost: defaults.maxImagesPerPost,
      imageCacheLimitMb: defaults.imageCacheLimitMb,
      recordReadingHistory: defaults.recordReadingHistory,
      fontSize: defaults.fontSize,
      shareImageFormat: defaults.shareImageFormat,
      sharePixelRatio: defaults.sharePixelRatio,
    );
    _commit(next);
    _persist('themeMode', defaults.themeMode);
    _persist('themeColor', defaults.themeColor);
    _persist('showImages', defaults.showImages);
    _persist('imageLoadPolicy', defaults.imageLoadPolicy.storageKey);
    _persist('avatarLoadPolicy', defaults.avatarLoadPolicy.storageKey);
    _persist('maxImagesPerPost', defaults.maxImagesPerPost);
    _persist('imageCacheLimitMb', defaults.imageCacheLimitMb);
    _applyImageCacheLimit(defaults.imageCacheLimitMb);
    _persist('recordReadingHistory', defaults.recordReadingHistory);
    _persist('fontSize', defaults.fontSize);
    _persist('shareImageFormat', defaults.shareImageFormat.storageKey);
    _persist('sharePixelRatio', defaults.sharePixelRatio);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
