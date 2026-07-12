/// How inline post images are fetched (aligned with S1-Next download gating).
enum ImageLoadPolicy {
  always,
  wifiOnly,
  manual;

  static ImageLoadPolicy fromStored(String? value) {
    switch (value) {
      case 'wifiOnly':
      case 'wifi_only':
        return ImageLoadPolicy.wifiOnly;
      case 'manual':
        return ImageLoadPolicy.manual;
      case 'always':
      default:
        return ImageLoadPolicy.always;
    }
  }

  String get storageKey {
    switch (this) {
      case ImageLoadPolicy.always:
        return 'always';
      case ImageLoadPolicy.wifiOnly:
        return 'wifiOnly';
      case ImageLoadPolicy.manual:
        return 'manual';
    }
  }

  String get backupKey {
    switch (this) {
      case ImageLoadPolicy.always:
        return 'always';
      case ImageLoadPolicy.wifiOnly:
        return 'wifi_only';
      case ImageLoadPolicy.manual:
        return 'manual';
    }
  }

  static ImageLoadPolicy fromBackup(String? value) {
    switch (value) {
      case 'wifi_only':
        return ImageLoadPolicy.wifiOnly;
      case 'manual':
        return ImageLoadPolicy.manual;
      case 'always':
      default:
        return ImageLoadPolicy.always;
    }
  }
}
