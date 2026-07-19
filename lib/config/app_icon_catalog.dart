/// Launcher icon variants available for user selection.
///
/// To add a new icon:
/// 1. Place a finished square PNG under `assets/branding/`
/// 2. Add an [AppIconVariant] here
/// 3. Run `dart run scripts/sync_app_icons.dart`
/// 4. Commit generated native resources
///
/// Rules:
/// - Default `black` reuses stock `@mipmap/ic_launcher` (flutter_launcher_icons).
/// - Solid-plate `white` reuses shared transparent fg + plate color + 16% inset
///   (same recipe as stock black).
/// - Finished themed masters (`androidMasterAsIcon`) are **only scaled** to
///   mipmap densities — no adaptive inset / no re-crop.
class AppIconVariant {
  const AppIconVariant({
    required this.id,
    required this.label,
    required this.previewAsset,
    required this.androidMipmap,
    required this.backgroundColor,
    this.masterPath,
    this.reuseExistingAndroid = false,
    this.androidMasterAsIcon = false,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String previewAsset;
  final String androidMipmap;

  /// Plate color for solid-plate adaptive variants (`#RRGGBB`).
  final String backgroundColor;

  final String? masterPath;
  final bool reuseExistingAndroid;

  /// When true, Android uses the master PNG as the launcher icon (mipmap only).
  final bool androidMasterAsIcon;

  final bool isDefault;
}

abstract final class AppIconCatalog {
  static const defaultId = 'black';

  static const adaptiveForegroundPath =
      'assets/branding/s1er_logo_transparent.png';

  static const adaptiveInsetPercent = 16;

  static const variants = <AppIconVariant>[
    AppIconVariant(
      id: 'black',
      label: '黑底',
      previewAsset: 'assets/branding/s1er_logo_black.png',
      androidMipmap: 'ic_launcher',
      backgroundColor: '#000000',
      reuseExistingAndroid: true,
      isDefault: true,
    ),
    AppIconVariant(
      id: 'white',
      label: '白底',
      previewAsset: 'assets/branding/s1er_logo_white.png',
      androidMipmap: 'ic_launcher_white',
      backgroundColor: '#FFFFFF',
      masterPath: 'assets/branding/s1er_logo_white.png',
    ),
    AppIconVariant(
      id: 'xb2',
      label: 'XB2',
      previewAsset: 'assets/branding/s1er_logo_xb2.png',
      androidMipmap: 'ic_launcher_xb2',
      backgroundColor: '#C45C8A',
      masterPath: 'assets/branding/s1er_logo_xb2.png',
      androidMasterAsIcon: true,
    ),
  ];

  static AppIconVariant get defaultVariant =>
      variants.firstWhere((v) => v.isDefault, orElse: () => variants.first);

  static AppIconVariant? find(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final v in variants) {
      if (v.id == id) return v;
    }
    return null;
  }

  static String normalize(String? id) => find(id)?.id ?? defaultId;

  static bool contains(String? id) => find(id) != null;

  static Iterable<AppIconVariant> get alternateVariants =>
      variants.where((v) => !v.isDefault);

  static Iterable<AppIconVariant> get androidGeneratedVariants =>
      variants.where((v) => !v.reuseExistingAndroid);
}
