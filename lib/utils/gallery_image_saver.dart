import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/share_save_mode.dart';
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

/// Result of a save image operation.
enum SaveImageResultStatus {
  success,
  cancelled,
  fallbackSuccess,
}

/// Saves image [bytes] to the system gallery or specified desktop folder.
///
/// Returns [SaveImageResultStatus] to indicate whether saved directly, via prompt or cancelled.
Future<SaveImageResultStatus> saveImageBytesToGallery({
  required Uint8List bytes,
  required String fileName,
  String? customDirectory,
  ShareSaveMode saveMode = ShareSaveMode.autoDir,
}) async {
  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  if (isDesktop) {
    if (saveMode == ShareSaveMode.promptSaveAs) {
      final saveLocation = await getSaveLocation(
        suggestedName: fileName,
      );
      if (saveLocation == null) {
        return SaveImageResultStatus.cancelled;
      }
      final file = File(saveLocation.path);
      await file.writeAsBytes(bytes);
      return SaveImageResultStatus.success;
    }

    if (customDirectory != null && customDirectory.trim().isNotEmpty) {
      final targetDir = Directory(customDirectory.trim());
      try {
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
        final targetPath = p.join(targetDir.path, fileName);
        await File(targetPath).writeAsBytes(bytes);
        return SaveImageResultStatus.success;
      } on Object {
        // Fallback to Gal / default system pictures folder on permission/directory failure
      }
    }
  }

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
  return (isDesktop &&
          customDirectory != null &&
          customDirectory.trim().isNotEmpty)
      ? SaveImageResultStatus.fallbackSuccess
      : SaveImageResultStatus.success;
}
