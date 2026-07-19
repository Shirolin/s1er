import 'package:flutter/foundation.dart';

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

class FlattenRgbaArgs {
  const FlattenRgbaArgs({
    required this.rgba,
    required this.width,
    required this.height,
    required this.bgR,
    required this.bgG,
    required this.bgB,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final int bgR;
  final int bgG;
  final int bgB;
}

Uint8List _flattenRgbaIsolate(FlattenRgbaArgs args) {
  return flattenRgbaOntoOpaqueRgba(
    rgba: args.rgba,
    width: args.width,
    height: args.height,
    bgR: args.bgR,
    bgG: args.bgG,
    bgB: args.bgB,
  );
}

/// 大图合成放到后台 isolate，避免分享导出卡主线程。
Future<Uint8List> flattenRgbaOntoOpaqueRgbaAsync({
  required Uint8List rgba,
  required int width,
  required int height,
  required int bgR,
  required int bgG,
  required int bgB,
}) {
  if (rgba.length < 256 * 1024) {
    return Future.value(
      flattenRgbaOntoOpaqueRgba(
        rgba: rgba,
        width: width,
        height: height,
        bgR: bgR,
        bgG: bgG,
        bgB: bgB,
      ),
    );
  }
  return compute(
    _flattenRgbaIsolate,
    FlattenRgbaArgs(
      rgba: rgba,
      width: width,
      height: height,
      bgR: bgR,
      bgG: bgG,
      bgB: bgB,
    ),
  );
}
