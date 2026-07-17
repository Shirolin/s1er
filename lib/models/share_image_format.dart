/// Format for exported share card images.
enum ShareImageFormat {
  webp,
  jpeg,
  png;

  String get storageKey {
    switch (this) {
      case ShareImageFormat.webp:
        return 'webp';
      case ShareImageFormat.jpeg:
        return 'jpeg';
      case ShareImageFormat.png:
        return 'png';
    }
  }

  String get backupKey => storageKey;

  /// Maps stored / backup values. Unknown / null → [webp].
  static ShareImageFormat fromStored(String? value) {
    switch (value) {
      case 'png':
        return ShareImageFormat.png;
      case 'jpeg':
        return ShareImageFormat.jpeg;
      case 'webp':
      default:
        return ShareImageFormat.webp;
    }
  }

  static ShareImageFormat fromBackup(String? value) => fromStored(value);

  String get extension {
    switch (this) {
      case ShareImageFormat.webp:
        return '.webp';
      case ShareImageFormat.jpeg:
        return '.jpg';
      case ShareImageFormat.png:
        return '.png';
    }
  }

  String get mimeType {
    switch (this) {
      case ShareImageFormat.webp:
        return 'image/webp';
      case ShareImageFormat.jpeg:
        return 'image/jpeg';
      case ShareImageFormat.png:
        return 'image/png';
    }
  }
}
