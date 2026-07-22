import 'package:flutter/foundation.dart';

/// One raw RGBA bitmap strip (same width as siblings when stitching).
class ShareRgbaStrip {
  const ShareRgbaStrip({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class _StitchArgs {
  const _StitchArgs(this.strips);

  final List<ShareRgbaStrip> strips;
}

ShareRgbaStrip stitchRgbaVertically(List<ShareRgbaStrip> strips) {
  if (strips.isEmpty) {
    throw ArgumentError('Cannot stitch an empty strip list');
  }
  final width = strips.first.width;
  if (width <= 0) {
    throw ArgumentError('Strip width must be positive');
  }

  var totalHeight = 0;
  for (final strip in strips) {
    if (strip.width != width) {
      throw ArgumentError(
        'Strip width mismatch: expected $width, got ${strip.width}',
      );
    }
    if (strip.height <= 0) {
      throw ArgumentError('Strip height must be positive');
    }
    final expected = strip.width * strip.height * 4;
    if (strip.bytes.length < expected) {
      throw ArgumentError(
        'RGBA buffer too short: ${strip.bytes.length} < $expected',
      );
    }
    totalHeight += strip.height;
  }

  final out = Uint8List(width * totalHeight * 4);
  var offset = 0;
  for (final strip in strips) {
    final byteCount = strip.width * strip.height * 4;
    out.setRange(offset, offset + byteCount, strip.bytes);
    offset += byteCount;
  }

  return ShareRgbaStrip(bytes: out, width: width, height: totalHeight);
}

ShareRgbaStrip _stitchIsolate(_StitchArgs args) =>
    stitchRgbaVertically(args.strips);

/// Vertical RGBA stitch; large buffers run in a background isolate.
Future<ShareRgbaStrip> stitchRgbaVerticallyAsync(
  List<ShareRgbaStrip> strips,
) {
  final approxBytes = strips.fold<int>(0, (sum, s) => sum + s.bytes.length);
  if (approxBytes < 256 * 1024) {
    return Future.value(stitchRgbaVertically(strips));
  }
  return compute(_stitchIsolate, _StitchArgs(strips));
}
