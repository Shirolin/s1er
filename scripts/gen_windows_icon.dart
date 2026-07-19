// Generate windows/runner/resources/app_icon.ico from branding master.
// Run: dart run scripts/gen_windows_icon.dart
//
// Multi-size ICO (16 / 32 / 48 / 256) so taskbar, title bar, and Explorer
// all get crisp glyphs — flutter_launcher_icons only emits a single 256 PNG.

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _source = 'assets/branding/s1er_logo_black.png';
const _dest = 'windows/runner/resources/app_icon.ico';
const _sizes = [16, 32, 48, 256];

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
      img.copyResize(
        decoded,
        width: size,
        height: size,
        interpolation: img.Interpolation.average,
      ),
  ];

  final icoBytes = img.IcoEncoder().encodeImages(frames);
  final destFile = File(p.join(root, _dest));
  await destFile.parent.create(recursive: true);
  await destFile.writeAsBytes(icoBytes, flush: true);
  stdout.writeln(
    'Wrote $_dest (${icoBytes.length} bytes, sizes ${_sizes.join('/')})',
  );
}
