import 'dart:typed_data';

import 'package:ironpress/ironpress.dart';

/// Encode a PNG buffer to lossy WebP (q=85) via ironpress / libwebp.
///
/// Returns null on native failure so the caller can fall back to PNG.
Future<Uint8List?> encodeShareWebpFromPng(Uint8List pngBytes) async {
  try {
    final result = await Ironpress.compressBytes(
      pngBytes,
      quality: 85,
      format: CompressFormat.webpLossy,
      allowResize: false,
    );
    return result.data;
  } on CompressException {
    return null;
  } on StateError {
    // flutter test / bare dart may not resolve plugin-bundled DLL paths.
    return null;
  }
}

/// Encode a PNG buffer to JPEG (q=85) via ironpress / mozjpeg.
Future<Uint8List?> encodeShareJpegFromPng(Uint8List pngBytes) async {
  try {
    final result = await Ironpress.compressBytes(
      pngBytes,
      quality: 85,
      format: CompressFormat.jpeg,
      allowResize: false,
    );
    return result.data;
  } on CompressException {
    return null;
  } on StateError {
    return null;
  }
}

/// Re-encode PNG via oxipng (usually smaller than engine Skia PNG).
///
/// Returns null on failure so the caller can keep the Skia PNG bytes.
Future<Uint8List?> encodeSharePngOptimized(Uint8List pngBytes) async {
  try {
    final result = await Ironpress.compressBytes(
      pngBytes,
      format: CompressFormat.png,
      allowResize: false,
      png: const PngOptions(optimizationLevel: 4),
    );
    return result.data;
  } on CompressException {
    return null;
  } on StateError {
    return null;
  }
}
