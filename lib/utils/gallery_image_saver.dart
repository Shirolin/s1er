import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'share_native_image_encoder.dart';

/// Whether [bytes] look like a RIFF/WebP container.
bool isWebpImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;
  return bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

/// Whether [bytes] look like a PNG signature.
bool isPngImageBytes(Uint8List bytes) {
  if (bytes.length < 8) return false;
  return bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
}

/// Whether [bytes] look like a JPEG SOI marker.
bool isJpegImageBytes(Uint8List bytes) {
  return bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
}

/// Saves image [bytes] to the system gallery.
///
/// Prefer temp file + [Gal.putImage] over [Gal.putImageBytes]:
///
/// - **Android**: `putImageBytes` uses commons-imaging `1.0-alpha3`, which
///   cannot sniff WebP (`Imaging.guessFormat` → `UNKNOWN` → `.bin`). That
///   breaks MediaStore inserts for share-card WebP exports. `putImage(path)`
///   uses the file extension instead and keeps `.webp`.
/// - If the OS / OEM still rejects WebP, fall back to a PNG re-encode.
///
/// [fileName] should include an extension matching [bytes] (e.g. `s1_1.webp`).
Future<void> saveImageBytesToGallery({
  required Uint8List bytes,
  required String fileName,
}) async {
  final dir = await getTemporaryDirectory();
  final path = p.join(dir.path, fileName);
  await XFile.fromData(bytes, name: fileName).saveTo(path);

  try {
    await Gal.putImage(path);
  } on GalException catch (_) {
    if (!isWebpImageBytes(bytes)) rethrow;

    // Some devices still reject WebP in the gallery pipeline — save PNG.
    final pngBytes = await encodeSharePngOptimized(bytes);
    if (pngBytes == null || !isPngImageBytes(pngBytes)) {
      rethrow;
    }

    final pngName = '${p.basenameWithoutExtension(fileName)}.png';
    final pngPath = p.join(dir.path, pngName);
    await XFile.fromData(pngBytes, name: pngName).saveTo(pngPath);
    await Gal.putImage(pngPath);
  }
}
