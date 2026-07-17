import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/share_image_format.dart';

void main() {
  group('ShareImageFormat', () {
    test('storageKey round-trips', () {
      expect(ShareImageFormat.jpeg.storageKey, 'jpeg');
      expect(ShareImageFormat.png.storageKey, 'png');

      expect(
        ShareImageFormat.fromStored(ShareImageFormat.jpeg.storageKey),
        ShareImageFormat.jpeg,
      );
      expect(
        ShareImageFormat.fromStored(ShareImageFormat.png.storageKey),
        ShareImageFormat.png,
      );
    });

    test('backupKey matches storageKey', () {
      expect(ShareImageFormat.jpeg.backupKey, 'jpeg');
      expect(ShareImageFormat.png.backupKey, 'png');
      expect(
        ShareImageFormat.fromBackup('jpeg'),
        ShareImageFormat.jpeg,
      );
      expect(ShareImageFormat.fromBackup('png'), ShareImageFormat.png);
    });

    test('default fromStored is png', () {
      expect(ShareImageFormat.fromStored(null), ShareImageFormat.png);
      expect(ShareImageFormat.fromStored(''), ShareImageFormat.png);
      expect(ShareImageFormat.fromStored('unknown'), ShareImageFormat.png);
    });

    test('extension matches format', () {
      expect(ShareImageFormat.jpeg.extension, '.jpg');
      expect(ShareImageFormat.png.extension, '.png');
    });

    test('mimeType matches format', () {
      expect(ShareImageFormat.jpeg.mimeType, 'image/jpeg');
      expect(ShareImageFormat.png.mimeType, 'image/png');
    });
  });
}
