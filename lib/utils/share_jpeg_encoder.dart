import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Parameters for isolate-friendly JPEG encoding of a share card capture.
class ShareJpegEncodeParams {
  const ShareJpegEncodeParams({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.bgR,
    required this.bgG,
    required this.bgB,
  });

  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final int bgR;
  final int bgG;
  final int bgB;
}

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
/// Used before browser canvas codecs, which treat transparent pixels as black.
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

/// Flatten unpremultiplied RGBA onto an opaque RGB background in one pass.
///
/// Avoids allocating a second full-frame [img.Image] and running
/// [img.compositeImage], which dominated share-card JPEG cost.
Uint8List flattenRgbaOntoRgb({
  required Uint8List rgba,
  required int width,
  required int height,
  required int bgR,
  required int bgG,
  required int bgB,
}) {
  _ensureRgbaLength(rgba, width, height);
  final pixelCount = width * height;

  final out = Uint8List(pixelCount * 3);
  var si = 0;
  var di = 0;
  for (var p = 0; p < pixelCount; p++) {
    final a = rgba[si + 3];
    if (a == 255) {
      out[di] = rgba[si];
      out[di + 1] = rgba[si + 1];
      out[di + 2] = rgba[si + 2];
    } else if (a == 0) {
      out[di] = bgR;
      out[di + 1] = bgG;
      out[di + 2] = bgB;
    } else {
      final inv = 255 - a;
      out[di] = (rgba[si] * a + bgR * inv) ~/ 255;
      out[di + 1] = (rgba[si + 1] * a + bgG * inv) ~/ 255;
      out[di + 2] = (rgba[si + 2] * a + bgB * inv) ~/ 255;
    }
    si += 4;
    di += 3;
  }
  return out;
}

/// Encode a captured share-card RGBA buffer to JPEG.
///
/// Uses 4:2:0 chroma and quality 85 — much faster than the previous
/// yuv444 + quality 90 path, with negligible visual difference for cards.
Uint8List encodeShareJpeg(ShareJpegEncodeParams params) {
  final rgb = flattenRgbaOntoRgb(
    rgba: params.rgbaBytes,
    width: params.width,
    height: params.height,
    bgR: params.bgR,
    bgG: params.bgG,
    bgB: params.bgB,
  );

  final image = img.Image.fromBytes(
    width: params.width,
    height: params.height,
    bytes: rgb.buffer,
    bytesOffset: rgb.offsetInBytes,
    rowStride: params.width * 3,
    numChannels: 3,
  );

  return img.encodeJpg(
    image,
    quality: 85,
    chroma: img.JpegChroma.yuv420,
  );
}
