// Generate windows/runner/resources/app_icon.ico from branding master.
// Run: dart run scripts/gen_windows_icon.dart
//
// Multi-size ICO (16 / 32 / 48 / 256) with Win11-style rounded corners
// (transparent outside the round-rect). Opaque square plates stay sharp on
// the taskbar — Windows does not round them for you.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _source = 'assets/branding/s1er_logo_black.png';
const _dest = 'windows/runner/resources/app_icon.ico';
const _sizes = [16, 32, 48, 256];

/// Corner radius as a fraction of icon size (~Win11 app icon plate).
const _cornerRadiusFraction = 0.22;

Future<void> main() async {
  final root = Directory.current.path;
  final sourceFile = File(p.join(root, _source));
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing $_source');
    exitCode = 1;
    return;
  }

  final decoded = img.decodeImage(await sourceFile.readAsBytes());
  if (decoded == null) {
    stderr.writeln('Failed to decode $_source');
    exitCode = 1;
    return;
  }

  final frames = <img.Image>[
    for (final size in _sizes)
      _applyRoundedCorners(
        img.copyResize(
          decoded,
          width: size,
          height: size,
          interpolation: img.Interpolation.average,
        ),
        radius: size * _cornerRadiusFraction,
      ),
  ];

  final icoBytes = img.IcoEncoder().encodeImages(frames);
  final destFile = File(p.join(root, _dest));
  await destFile.parent.create(recursive: true);
  await destFile.writeAsBytes(icoBytes, flush: true);
  stdout.writeln(
    'Wrote $_dest (${icoBytes.length} bytes, sizes ${_sizes.join('/')}, '
    'corner r≈${(_cornerRadiusFraction * 100).round()}%)',
  );
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
