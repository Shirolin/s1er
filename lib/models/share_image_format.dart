/// Format for exported share card images.
enum ShareImageFormat {
  jpeg,
  png;

  String get storageKey {
    switch (this) {
      case ShareImageFormat.jpeg:
        return 'jpeg';
      case ShareImageFormat.png:
        return 'png';
    }
  }

  String get backupKey => storageKey;

  static ShareImageFormat fromStored(String? value) {
    switch (value) {
      case 'png':
        return ShareImageFormat.png;
      case 'jpeg':
      default:
        return ShareImageFormat.jpeg;
    }
  }

  static ShareImageFormat fromBackup(String? value) => fromStored(value);

  String get extension {
    switch (this) {
      case ShareImageFormat.jpeg:
        return '.jpg';
      case ShareImageFormat.png:
        return '.png';
    }
  }

  String get mimeType {
    switch (this) {
      case ShareImageFormat.jpeg:
        return 'image/jpeg';
      case ShareImageFormat.png:
        return 'image/png';
    }
  }
}
