import 'dart:typed_data';

void _ensureRgbaLength(Uint8List rgba, int width, int height) {
  final pixelCount = width * height;
  if (rgba.length < pixelCount * 4) {
    throw ArgumentError(
      'RGBA buffer too short: ${rgba.length} < ${pixelCount * 4}',
    );
  }
}

/// Flatten unpremultiplied RGBA onto an opaque background (alpha forced to 255).
///
/// Used before lossy codecs and browser canvas, which treat transparent
/// pixels as black.
Uint8List flattenRgbaOntoOpaqueRgba({
  required Uint8List rgba,
  required int width,
  required int height,
  required int bgR,
  required int bgG,
  required int bgB,
}) {
  _ensureRgbaLength(rgba, width, height);
  final pixelCount = width * height;
  final out = Uint8List(pixelCount * 4);
  var i = 0;
  for (var p = 0; p < pixelCount; p++) {
    final a = rgba[i + 3];
    if (a == 255) {
      out[i] = rgba[i];
      out[i + 1] = rgba[i + 1];
      out[i + 2] = rgba[i + 2];
    } else if (a == 0) {
      out[i] = bgR;
      out[i + 1] = bgG;
      out[i + 2] = bgB;
    } else {
      final inv = 255 - a;
      out[i] = (rgba[i] * a + bgR * inv) ~/ 255;
      out[i + 1] = (rgba[i + 1] * a + bgG * inv) ~/ 255;
      out[i + 2] = (rgba[i + 2] * a + bgB * inv) ~/ 255;
    }
    out[i + 3] = 255;
    i += 4;
  }
  return out;
}
