import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_icon_catalog.dart';
import '../models/image_load_policy.dart';
import '../models/list_density.dart';
import '../models/share_save_mode.dart';
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
    this.compactListFullBleed = false,
    this.threadListFiltersExpanded = false,
    this.fontSize = S1Typography.defaultBodySize,
    this.collapsedForums = const {},
    this.hiddenForums = const {},
    this.favoriteForumOrder = const [],
    this.shareImageFormat = ShareImageFormat.webp,
    this.sharePixelRatio = SharePixelRatio.defaultValue,
    this.shareAdvancedExport = false,
    this.shareShowQr = true,
    this.shareSaveMode = ShareSaveMode.autoDir,
    this.customExportPath,
    this.postSignatureEnabled = true,
    this.postSignatureShowDevice = true,
    this.postSignatureCustom = '',
    this.customFontFileName,
    this.forumSplitListPaneWidth,
    this.stripSpecialStyles = false,
    this.hideStickyThreads = false,
    this.hideStickyForumOverrides = const {},
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

  /// Compact windows (≤599dp): thread list / post floors go edge-to-edge.
  final bool compactListFullBleed;
  final bool threadListFiltersExpanded;
  final int fontSize;
  final Set<String> collapsedForums;
  final Set<String> hiddenForums;
  final List<String> favoriteForumOrder;
  final ShareImageFormat shareImageFormat;
  final double sharePixelRatio;
  final bool shareAdvancedExport;
  final bool shareShowQr;
  final ShareSaveMode shareSaveMode;
  final String? customExportPath;
  final bool postSignatureEnabled;
  final bool postSignatureShowDevice;
  final String postSignatureCustom;
  final String? customFontFileName;
  final double? forumSplitListPaneWidth;

  /// 全局去除帖子中的作者特殊样式（字色 / 底色 / 字号）。
  final bool stripSpecialStyles;

  /// 全局默认隐藏各版块置顶帖。
  final bool hideStickyThreads;

  /// 与全局相反的板块例外（fid 列表）：包含某 fid 表示该版块单独覆盖全局开关。
  final Set<String> hideStickyForumOverrides;

  /// 某版块实际生效的「隐藏置顶帖」值（全局 XOR 板块例外）。
  bool hideStickyEffectiveFor(String fid) =>
      hideStickyThreads != hideStickyForumOverrides.contains(fid);

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
    bool? compactListFullBleed,
    bool? threadListFiltersExpanded,
    int? fontSize,
    Set<String>? collapsedForums,
    Set<String>? hiddenForums,
    List<String>? favoriteForumOrder,
    ShareImageFormat? shareImageFormat,
    double? sharePixelRatio,
    bool? shareAdvancedExport,
    bool? shareShowQr,
    ShareSaveMode? shareSaveMode,
    Object? customExportPath = _Sentinel.value,
    bool? postSignatureEnabled,
    bool? postSignatureShowDevice,
    String? postSignatureCustom,
    Object? customFontFileName = _Sentinel.value,
    Object? forumSplitListPaneWidth = _Sentinel.value,
    bool? stripSpecialStyles,
    bool? hideStickyThreads,
    Set<String>? hideStickyForumOverrides,
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
      compactListFullBleed: compactListFullBleed ?? this.compactListFullBleed,
      threadListFiltersExpanded:
          threadListFiltersExpanded ?? this.threadListFiltersExpanded,
      fontSize: fontSize ?? this.fontSize,
      collapsedForums: collapsedForums ?? this.collapsedForums,
      hiddenForums: hiddenForums ?? this.hiddenForums,
      favoriteForumOrder: favoriteForumOrder ?? this.favoriteForumOrder,
      shareImageFormat: shareImageFormat ?? this.shareImageFormat,
      sharePixelRatio: sharePixelRatio ?? this.sharePixelRatio,
      shareAdvancedExport: shareAdvancedExport ?? this.shareAdvancedExport,
      shareShowQr: shareShowQr ?? this.shareShowQr,
      shareSaveMode: shareSaveMode ?? this.shareSaveMode,
      customExportPath: customExportPath == _Sentinel.value
          ? this.customExportPath
          : customExportPath as String?,
      postSignatureEnabled: postSignatureEnabled ?? this.postSignatureEnabled,
      postSignatureShowDevice:
          postSignatureShowDevice ?? this.postSignatureShowDevice,
      postSignatureCustom: postSignatureCustom ?? this.postSignatureCustom,
      customFontFileName: customFontFileName == _Sentinel.value
          ? this.customFontFileName
          : customFontFileName as String?,
      forumSplitListPaneWidth: forumSplitListPaneWidth == _Sentinel.value
          ? this.forumSplitListPaneWidth
          : forumSplitListPaneWidth as double?,
      stripSpecialStyles: stripSpecialStyles ?? this.stripSpecialStyles,
      hideStickyThreads: hideStickyThreads ?? this.hideStickyThreads,
      hideStickyForumOverrides:
          hideStickyForumOverrides ?? this.hideStickyForumOverrides,
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
        other.compactListFullBleed == compactListFullBleed &&
        other.threadListFiltersExpanded == threadListFiltersExpanded &&
        other.fontSize == fontSize &&
        _setEquals(other.collapsedForums, collapsedForums) &&
        _setEquals(other.hiddenForums, hiddenForums) &&
        listEquals(other.favoriteForumOrder, favoriteForumOrder) &&
        other.shareImageFormat == shareImageFormat &&
        other.sharePixelRatio == sharePixelRatio &&
        other.shareAdvancedExport == shareAdvancedExport &&
        other.shareShowQr == shareShowQr &&
        other.shareSaveMode == shareSaveMode &&
        other.customExportPath == customExportPath &&
        other.postSignatureEnabled == postSignatureEnabled &&
        other.postSignatureShowDevice == postSignatureShowDevice &&
        other.postSignatureCustom == postSignatureCustom &&
        other.customFontFileName == customFontFileName &&
        other.forumSplitListPaneWidth == forumSplitListPaneWidth &&
        other.stripSpecialStyles == stripSpecialStyles &&
        other.hideStickyThreads == hideStickyThreads &&
        _setEquals(
          other.hideStickyForumOverrides,
          hideStickyForumOverrides,
        );
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
        Object.hashAllUnordered(hiddenForums),
        Object.hashAll(favoriteForumOrder),
        shareImageFormat,
        sharePixelRatio,
        Object.hash(
          compactListFullBleed,
          threadListFiltersExpanded,
          shareAdvancedExport,
          shareShowQr,
          shareSaveMode,
          customExportPath,
        ),
        Object.hash(
          postSignatureEnabled,
          postSignatureShowDevice,
          postSignatureCustom,
          customFontFileName,
          forumSplitListPaneWidth,
          stripSpecialStyles,
          hideStickyThreads,
          Object.hashAllUnordered(hideStickyForumOverrides),
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
      compactListFullBleed: settingsStore.get<bool>(
            'compactListFullBleed',
            defaultValue: false,
          ) ??
          false,
      threadListFiltersExpanded: settingsStore.get<bool>(
            'threadListFiltersExpanded',
            defaultValue: false,
          ) ??
          false,
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
      shareAdvancedExport: settingsStore.get<bool>(
            'shareAdvancedExport',
            defaultValue: false,
          ) ??
          false,
      shareShowQr: settingsStore.get<bool>(
            'shareShowQr',
            defaultValue: true,
          ) ??
          true,
      shareSaveMode: ShareSaveMode.values.firstWhere(
        (e) => e.name == settingsStore.get<String>('shareSaveMode'),
        orElse: () => ShareSaveMode.autoDir,
      ),
      customExportPath: settingsStore.get<String>('customExportPath'),
      collapsedForums: Set<String>.from(
        (settingsStore.get<List<dynamic>>('collapsedForums'))?.cast<String>() ??
            [],
      ),
      hiddenForums: Set<String>.from(
        (settingsStore.get<List<dynamic>>('hiddenForums'))?.cast<String>() ??
            [],
      ),
      favoriteForumOrder: List<String>.from(
        (settingsStore.get<List<dynamic>>('favoriteForumOrder'))
                ?.cast<String>() ??
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
      forumSplitListPaneWidth: _readForumSplitListPaneWidth(settingsStore),
      stripSpecialStyles: settingsStore.get<bool>(
            'stripSpecialStyles',
            defaultValue: false,
          ) ??
          false,
      hideStickyThreads: settingsStore.get<bool>(
            'hideStickyThreads',
            defaultValue: false,
          ) ??
          false,
      hideStickyForumOverrides: Set<String>.from(
        (settingsStore.get<List<dynamic>>('hideStickyForumOverrides'))
                ?.cast<String>() ??
            [],
      ),
    );
  }

  double? _readForumSplitListPaneWidth(SettingsStore settingsStore) {
    final raw = settingsStore.get<Object>('forumSplitListPaneWidth');
    if (raw is num) return raw.toDouble();
    return null;
  }

  void setShareSaveMode(ShareSaveMode value) {
    _commit(state.copyWith(shareSaveMode: value));
    _persist('shareSaveMode', value.name);
  }

  void setCustomExportPath(String? path) {
    _commit(state.copyWith(customExportPath: path));
    _persist('customExportPath', path);
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

  void setThreadListFiltersExpanded(bool value) {
    _commit(state.copyWith(threadListFiltersExpanded: value));
    _persist('threadListFiltersExpanded', value);
  }

  void setPostListDensity(ListDensity value) {
    _commit(state.copyWith(postListDensity: value));
    _persist('postListDensity', value.storageKey);
  }

  void setCompactListFullBleed(bool value) {
    _commit(state.copyWith(compactListFullBleed: value));
    _persist('compactListFullBleed', value);
  }

  void setForumSplitListPaneWidth(double? value) {
    _commit(state.copyWith(forumSplitListPaneWidth: value));
    _persist('forumSplitListPaneWidth', value);
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

  void setShareAdvancedExport(bool value) {
    _commit(state.copyWith(shareAdvancedExport: value));
    _persist('shareAdvancedExport', value);
  }

  void setShareShowQr(bool value) {
    _commit(state.copyWith(shareShowQr: value));
    _persist('shareShowQr', value);
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

  void setStripSpecialStyles(bool value) {
    _commit(state.copyWith(stripSpecialStyles: value));
    _persist('stripSpecialStyles', value);
  }

  void setHideStickyThreads(bool value) {
    _commit(state.copyWith(hideStickyThreads: value));
    _persist('hideStickyThreads', value);
  }

  void toggleHideStickyForum(String fid) {
    if (fid.isEmpty) return;
    final overrides = Set<String>.from(state.hideStickyForumOverrides);
    if (overrides.contains(fid)) {
      overrides.remove(fid);
    } else {
      overrides.add(fid);
    }
    _commit(state.copyWith(hideStickyForumOverrides: overrides));
    _persist('hideStickyForumOverrides', overrides.toList());
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

  void hideForum(String fid) {
    if (fid.isEmpty || state.hiddenForums.contains(fid)) return;
    final hidden = Set<String>.from(state.hiddenForums)..add(fid);
    _commit(state.copyWith(hiddenForums: hidden));
    _persist('hiddenForums', hidden.toList());
  }

  void unhideForum(String fid) {
    if (fid.isEmpty || !state.hiddenForums.contains(fid)) return;
    final hidden = Set<String>.from(state.hiddenForums)..remove(fid);
    _commit(state.copyWith(hiddenForums: hidden));
    _persist('hiddenForums', hidden.toList());
  }

  void clearHiddenForums() {
    if (state.hiddenForums.isEmpty) return;
    _commit(state.copyWith(hiddenForums: const {}));
    _persist('hiddenForums', <String>[]);
  }

  void reorderFavoriteForums(List<String> orderedFids) {
    final cleaned = [
      for (final fid in orderedFids)
        if (fid.isNotEmpty) fid,
    ];
    _commit(state.copyWith(favoriteForumOrder: cleaned));
    _persist('favoriteForumOrder', cleaned);
  }

  void removeFavoriteForumFromOrder(String fid) {
    if (fid.isEmpty || !state.favoriteForumOrder.contains(fid)) return;
    final order = List<String>.from(state.favoriteForumOrder)..remove(fid);
    _commit(state.copyWith(favoriteForumOrder: order));
    _persist('favoriteForumOrder', order);
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
      compactListFullBleed: defaults.compactListFullBleed,
      threadListFiltersExpanded: defaults.threadListFiltersExpanded,
      fontSize: defaults.fontSize,
      shareImageFormat: defaults.shareImageFormat,
      sharePixelRatio: defaults.sharePixelRatio,
      shareAdvancedExport: defaults.shareAdvancedExport,
      shareShowQr: defaults.shareShowQr,
      shareSaveMode: defaults.shareSaveMode,
      customExportPath: defaults.customExportPath,
      customFontFileName: null,
      stripSpecialStyles: defaults.stripSpecialStyles,
      hideStickyThreads: defaults.hideStickyThreads,
      hideStickyForumOverrides: defaults.hideStickyForumOverrides,
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
    _persist('compactListFullBleed', defaults.compactListFullBleed);
    _persist('threadListFiltersExpanded', defaults.threadListFiltersExpanded);
    _persist('fontSize', defaults.fontSize);
    _persist('shareImageFormat', defaults.shareImageFormat.storageKey);
    _persist('sharePixelRatio', defaults.sharePixelRatio);
    _persist('shareAdvancedExport', defaults.shareAdvancedExport);
    _persist('shareShowQr', defaults.shareShowQr);
    _persist('shareSaveMode', defaults.shareSaveMode.name);
    _persist('customExportPath', defaults.customExportPath);
    _persist('customFontFileName', null);
    _persist('stripSpecialStyles', defaults.stripSpecialStyles);
    _persist('hideStickyThreads', defaults.hideStickyThreads);
    _persist(
      'hideStickyForumOverrides',
      defaults.hideStickyForumOverrides.toList(),
    );
    // Best-effort native align; failures are logged inside sync.
    // ignore: discarded_futures
    syncAppIconWithNative();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
