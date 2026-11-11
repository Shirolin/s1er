import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Sizes embedded in generated Windows shortcut icons (mirrors
/// `scripts/gen_windows_icon.dart`).
const kWindowsIconSizes = <int>[16, 32, 48, 256];

/// Corner radius as a fraction of icon size (~Win11 app icon plate).
const kWindowsIconCornerRadiusFraction = 0.22;

/// Builds a multi-size ICO with Win11-style rounded corners from a PNG.
Uint8List buildWindowsIco(
  Uint8List source, {
  List<int> sizes = kWindowsIconSizes,
}) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('Unsupported icon image');
  }

  final frames = <img.Image>[
    for (final size in sizes)
      _applyRoundedCorners(
        img.copyResize(
          decoded,
          width: size,
          height: size,
          interpolation: img.Interpolation.average,
        ),
        radius: size * kWindowsIconCornerRadiusFraction,
      ),
  ];
  return img.IcoEncoder().encodeImages(frames);
}

/// Soft-masks [src] to a rounded rectangle; pixels outside become transparent.
img.Image _applyRoundedCorners(img.Image src, {required double radius}) {
  final size = src.width;
  final out = img.Image(width: size, height: size, numChannels: 4);
  final r = radius.clamp(1.0, size / 2.0);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final coverage = _roundedRectCoverage(
        px: x + 0.5,
        py: y + 0.5,
        size: size.toDouble(),
        radius: r,
      );
      final p = src.getPixel(x, y);
      final a = (p.aNormalized * coverage * 255.0).round().clamp(0, 255);
      out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), a);
    }
  }
  return out;
}

/// 1 = fully inside, 0 = fully outside (with ~1px AA on the arc/edge).
double _roundedRectCoverage({
  required double px,
  required double py,
  required double size,
  required double radius,
}) {
  if (px < 0 || py < 0 || px > size || py > size) return 0;

  final inCornerX = px < radius || px > size - radius;
  final inCornerY = py < radius || py > size - radius;

  if (inCornerX && inCornerY) {
    final cx = px < radius ? radius : size - radius;
    final cy = py < radius ? radius : size - radius;
    final dist = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
    return ((radius + 0.5) - dist).clamp(0.0, 1.0);
  }

  return 1.0;
}
