import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Stages ironpress's prebuilt native library where [ironpress]'s loader looks
/// during `flutter test` (project `*/libs/`), copying from the pub-cache package.
///
/// Packaged app builds already bundle the lib via the plugin CMake/Gradle rules.
Future<void> ensureIronpressTestNativeLib() async {
  if (kIsWeb) return;

  late final String platformDir;
  late final String libFileName;

  if (Platform.isWindows) {
    platformDir = 'windows';
    libFileName = 'ironpress.dll';
  } else if (Platform.isLinux) {
    platformDir = 'linux';
    libFileName = 'libironpress.so';
  } else if (Platform.isMacOS) {
    platformDir = 'macos';
    libFileName = 'libironpress.dylib';
  } else {
    return;
  }

  final dest = File('$platformDir/libs/$libFileName');
  if (dest.existsSync()) return;

  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) return;

  final decoded =
      jsonDecode(await packageConfig.readAsString()) as Map<String, dynamic>;
  final packages = decoded['packages'] as List<dynamic>;
  Map<String, dynamic>? ironpressPkg;
  for (final entry in packages) {
    final map = entry as Map<String, dynamic>;
    if (map['name'] == 'ironpress') {
      ironpressPkg = map;
      break;
    }
  }
  if (ironpressPkg == null) return;

  final rootUri = Uri.parse(ironpressPkg['rootUri'] as String);
  var resolvedRoot = rootUri.isAbsolute
      ? rootUri
      : packageConfig.parent.uri.resolveUri(rootUri);
  // package_config rootUri often omits a trailing slash; without it,
  // Uri.resolve replaces the final path segment instead of joining.
  if (!resolvedRoot.path.endsWith('/')) {
    resolvedRoot = Uri.parse('$resolvedRoot/');
  }
  final source = File.fromUri(
    resolvedRoot.resolve('$platformDir/libs/$libFileName'),
  );
  if (!source.existsSync()) return;

  await dest.parent.create(recursive: true);
  await source.copy(dest.path);
}
