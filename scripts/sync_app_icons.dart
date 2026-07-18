// scripts/sync_app_icons.dart
// Run with: dart run scripts/sync_app_icons.dart
//
// Android default (black) REUSES existing flutter_launcher_icons output
// (@mipmap/ic_launcher) — never regenerate it.
//
// Alternate Android icons use the same adaptive recipe:
//   solid background + assets/branding/s1er_logo_transparent.png + 16% inset
// Legacy mipmaps for alternates are scaled from the variant master PNG.
//
// Steps to add an icon:
// 1. Add preview + master under assets/branding/
// 2. Add AppIconVariant in lib/config/app_icon_catalog.dart
// 3. dart run scripts/sync_app_icons.dart
// 4. Commit generated android/ / ios/ resources

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:s1er/config/app_icon_catalog.dart';

const _androidManifestMarkers = (
  begin: '<!-- APP_ICON_ALIASES_BEGIN -->',
  end: '<!-- APP_ICON_ALIASES_END -->',
);

const _iosPlistMarkers = (
  begin: '<!-- APP_ICON_ALTERNATE_BEGIN -->',
  end: '<!-- APP_ICON_ALTERNATE_END -->',
);

const _pbxBuildFileMarkers = (
  begin: '/* APP_ICON_PBX_BUILD_FILE_BEGIN */',
  end: '/* APP_ICON_PBX_BUILD_FILE_END */',
);

const _pbxFileRefMarkers = (
  begin: '/* APP_ICON_PBX_FILE_REF_BEGIN */',
  end: '/* APP_ICON_PBX_FILE_REF_END */',
);

const _pbxGroupMarkers = (
  begin: '/* APP_ICON_PBX_GROUP_BEGIN */',
  end: '/* APP_ICON_PBX_GROUP_END */',
);

const _pbxResourcesMarkers = (
  begin: '/* APP_ICON_PBX_RESOURCES_BEGIN */',
  end: '/* APP_ICON_PBX_RESOURCES_END */',
);

const _mipmapSizes = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

Future<void> main() async {
  final root = Directory.current.path;
  stdout.writeln('Syncing app icons from AppIconCatalog…');
  stdout.writeln(
    'Android black → reuse @mipmap/ic_launcher; '
    'others → adaptive (transparent + ${AppIconCatalog.adaptiveInsetPercent}% inset).',
  );

  await _cleanupOrphanBlackMipmaps(root);

  for (final variant in AppIconCatalog.androidGeneratedVariants) {
    final masterPath = variant.masterPath;
    if (masterPath == null) {
      stderr.writeln('Missing masterPath for ${variant.id}');
      exitCode = 1;
      return;
    }
    final masterFile = File(p.join(root, masterPath));
    if (!masterFile.existsSync()) {
      stderr.writeln('Missing master: $masterPath');
      exitCode = 1;
      return;
    }
    final bytes = await masterFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      stderr.writeln('Failed to decode: $masterPath');
      exitCode = 1;
      return;
    }
    await _writeAndroidAlternate(root, variant, decoded);
    stdout.writeln('  Android: ${variant.id} → ${variant.androidMipmap}');
  }

  await _patchAndroidManifest(root);
  await _writeIosAlternateIcons(root);
  await _patchIosInfoPlist(root);
  await _patchIosPbxproj(root);

  stdout.writeln('Done.');
}

/// Removes mistaken `ic_launcher_black` assets from earlier sync attempts.
Future<void> _cleanupOrphanBlackMipmaps(String root) async {
  final res = p.join(root, 'android', 'app', 'src', 'main', 'res');
  for (final density in _mipmapSizes.keys) {
    final file = File(p.join(res, 'mipmap-$density', 'ic_launcher_black.png'));
    if (file.existsSync()) {
      file.deleteSync();
      stdout.writeln('  Removed orphan ${file.path}');
    }
  }
  final adaptive =
      File(p.join(res, 'mipmap-anydpi-v26', 'ic_launcher_black.xml'));
  if (adaptive.existsSync()) {
    adaptive.deleteSync();
  }
}

/// Alternate icons: same adaptive recipe as flutter_launcher_icons default.
Future<void> _writeAndroidAlternate(
  String root,
  AppIconVariant variant,
  img.Image master,
) async {
  final res = p.join(root, 'android', 'app', 'src', 'main', 'res');
  final name = variant.androidMipmap;
  final bgName = '${name}_background';

  // Legacy mipmaps: scale the precomposed master (parity with image_path).
  for (final entry in _mipmapSizes.entries) {
    final dir = Directory(p.join(res, 'mipmap-${entry.key}'));
    dir.createSync(recursive: true);
    final resized = img.copyResize(
      master,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.average,
    );
    await File(p.join(dir.path, '$name.png'))
        .writeAsBytes(img.encodePng(resized));
  }

  // Adaptive: solid bg + shared transparent foreground + 16% inset.
  // Reuses @drawable/ic_launcher_foreground from flutter_launcher_icons.
  final anydpi = Directory(p.join(res, 'mipmap-anydpi-v26'));
  anydpi.createSync(recursive: true);
  final inset = AppIconCatalog.adaptiveInsetPercent;
  await File(p.join(anydpi.path, '$name.xml')).writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/$bgName"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground"
          android:inset="$inset%" />
  </foreground>
</adaptive-icon>
'''
      .trimLeft());

  await _upsertColorResource(root, bgName, variant.backgroundColor);
}

Future<void> _upsertColorResource(
  String root,
  String name,
  String hex,
) async {
  final file = File(
    p.join(
        root, 'android', 'app', 'src', 'main', 'res', 'values', 'colors.xml'),
  );
  var content = await file.readAsString();
  final colorLine = '    <color name="$name">$hex</color>';
  final re = RegExp(
    '<color name="${RegExp.escape(name)}">[^<]*</color>',
  );
  if (re.hasMatch(content)) {
    content = content.replaceFirst(re, '<color name="$name">$hex</color>');
  } else {
    content = content.replaceFirst(
      '</resources>',
      '$colorLine\n</resources>',
    );
  }
  await file.writeAsString(content);
}

String _aliasComponentName(String id) {
  final capitalized = id[0].toUpperCase() + id.substring(1);
  return 'Icon$capitalized';
}

Future<void> _patchAndroidManifest(String root) async {
  final file = File(
    p.join(root, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  var content = await file.readAsString();

  final aliases = StringBuffer();
  aliases.writeln('        ${_androidManifestMarkers.begin}');
  for (final variant in AppIconCatalog.variants) {
    final component = _aliasComponentName(variant.id);
    final enabled = variant.isDefault ? 'true' : 'false';
    aliases.writeln('''
        <activity-alias
            android:name=".$component"
            android:enabled="$enabled"
            android:exported="true"
            android:icon="@mipmap/${variant.androidMipmap}"
            android:label="S1er"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>''');
  }
  aliases.write('        ${_androidManifestMarkers.end}');

  content = _replaceMarkedRegion(
    content,
    begin: _androidManifestMarkers.begin,
    end: _androidManifestMarkers.end,
    replacement: aliases.toString(),
  );

  content = content.replaceAllMapped(
    RegExp(
      r'(<activity\s+android:name="\.MainActivity"[\s\S]*?>)([\s\S]*?)(</activity>)',
    ),
    (match) {
      final open = match.group(1)!;
      var body = match.group(2)!;
      final close = match.group(3)!;
      body = body.replaceAll(
        RegExp(
          r'\s*<intent-filter>\s*'
          r'<action android:name="android\.intent\.action\.MAIN"/>\s*'
          r'<category android:name="android\.intent\.category\.LAUNCHER"/>\s*'
          r'</intent-filter>',
        ),
        '\n',
      );
      return '$open$body$close';
    },
  );

  if (!content.contains(_androidManifestMarkers.begin)) {
    content = content.replaceFirst(
      '</activity>',
      '</activity>\n${aliases.toString()}',
    );
  }

  final defaultMipmap = AppIconCatalog.defaultVariant.androidMipmap;
  content = content.replaceFirst(
    RegExp(r'android:icon="@mipmap/ic_launcher[^"]*"'),
    'android:icon="@mipmap/$defaultMipmap"',
  );

  await file.writeAsString(content);
  stdout.writeln('  AndroidManifest aliases updated');
}

Future<void> _writeIosAlternateIcons(String root) async {
  final dir = Directory(p.join(root, 'ios', 'Runner', 'AlternateAppIcons'));
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  dir.createSync(recursive: true);

  for (final variant in AppIconCatalog.alternateVariants) {
    final masterPath = variant.masterPath;
    if (masterPath == null) continue;
    final masterFile = File(p.join(root, masterPath));
    final bytes = await masterFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) continue;

    for (final entry in const {'2x': 120, '3x': 180}.entries) {
      final resized = img.copyResize(
        decoded,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.average,
      );
      final name = 'AppIcon-${variant.id}@${entry.key}.png';
      await File(p.join(dir.path, name)).writeAsBytes(img.encodePng(resized));
    }
    stdout.writeln('  iOS alternate: ${variant.id}');
  }
}

Future<void> _patchIosInfoPlist(String root) async {
  final file = File(p.join(root, 'ios', 'Runner', 'Info.plist'));
  var content = await file.readAsString();
  content = content.replaceAll('\r\n', '\n');

  final alternateEntries = StringBuffer();
  for (final variant in AppIconCatalog.alternateVariants) {
    alternateEntries.writeln('''
			<key>${variant.id}</key>
			<dict>
				<key>CFBundleIconFiles</key>
				<array>
					<string>AppIcon-${variant.id}</string>
				</array>
				<key>UIPrerenderedIcon</key>
				<false/>
			</dict>''');
  }

  final block = '''
	<key>CFBundleIcons</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict>
			<key>CFBundleIconFiles</key>
			<array>
				<string>AppIcon</string>
			</array>
			<key>UIPrerenderedIcon</key>
			<false/>
		</dict>
		<key>CFBundleAlternateIcons</key>
		<dict>
			${_iosPlistMarkers.begin}
${alternateEntries.toString().trimRight()}
			${_iosPlistMarkers.end}
		</dict>
	</dict>
	<key>UIApplicationSupportsAlternateIcons</key>
	<true/>''';

  content = content.replaceAll(
    RegExp(
      r'\t<key>CFBundleIcons</key>\s*<dict>[\s\S]*?</dict>\s*'
      r'(?:\t<key>UIApplicationSupportsAlternateIcons</key>\s*<true/>\s*)?',
    ),
    '',
  );
  content = content.replaceAll(
    RegExp(
      r'\t<key>UIApplicationSupportsAlternateIcons</key>\s*<true/>\s*',
    ),
    '',
  );

  final closing = RegExp(r'</dict>\s*</plist>\s*$');
  if (!closing.hasMatch(content)) {
    stderr.writeln('Warning: could not find Info.plist closing tags');
    return;
  }
  content = content.replaceFirst(closing, '$block\n</dict>\n</plist>\n');

  await file.writeAsString(content);
  stdout.writeln('  Info.plist CFBundleAlternateIcons updated');
}

String _pbxId(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  final hex = (hash.toRadixString(16) + seed.hashCode.toRadixString(16))
      .replaceAll('-', '')
      .padRight(24, '0')
      .substring(0, 24)
      .toUpperCase();
  return hex;
}

Future<void> _patchIosPbxproj(String root) async {
  final file = File(p.join(root, 'ios', 'Runner.xcodeproj', 'project.pbxproj'));
  var content = await file.readAsString();

  final fileNames = <String>[];
  for (final variant in AppIconCatalog.alternateVariants) {
    fileNames.add('AppIcon-${variant.id}@2x.png');
    fileNames.add('AppIcon-${variant.id}@3x.png');
  }

  final buildFiles = StringBuffer()..writeln(_pbxBuildFileMarkers.begin);
  final fileRefs = StringBuffer()..writeln(_pbxFileRefMarkers.begin);
  final groupChildren = StringBuffer()..writeln(_pbxGroupMarkers.begin);
  final resources = StringBuffer()..writeln(_pbxResourcesMarkers.begin);

  for (final name in fileNames) {
    final refId = _pbxId('fileref-$name');
    final buildId = _pbxId('build-$name');
    buildFiles.writeln(
      '\t\t$buildId /* $name in Resources */ = '
      '{isa = PBXBuildFile; fileRef = $refId /* $name */; };',
    );
    fileRefs.writeln(
      '\t\t$refId /* $name */ = '
      '{isa = PBXFileReference; lastKnownFileType = image.png; '
      'name = "$name"; path = "AlternateAppIcons/$name"; '
      'sourceTree = "<group>"; };',
    );
    groupChildren.writeln('\t\t\t\t$refId /* $name */,');
    resources.writeln('\t\t\t\t$buildId /* $name in Resources */,');
  }

  buildFiles.write(_pbxBuildFileMarkers.end);
  fileRefs.write(_pbxFileRefMarkers.end);
  groupChildren.write(_pbxGroupMarkers.end);
  resources.write(_pbxResourcesMarkers.end);

  content = _ensureMarkedInsert(
    content,
    begin: _pbxBuildFileMarkers.begin,
    end: _pbxBuildFileMarkers.end,
    replacement: buildFiles.toString(),
    insertAfter: '/* Begin PBXBuildFile section */\n',
  );
  content = _ensureMarkedInsert(
    content,
    begin: _pbxFileRefMarkers.begin,
    end: _pbxFileRefMarkers.end,
    replacement: fileRefs.toString(),
    insertAfter: '/* Begin PBXFileReference section */\n',
  );

  final groupBlock = '${groupChildren.toString()}\n';
  if (!content.contains(_pbxGroupMarkers.begin)) {
    content = content.replaceFirst(
      '97C147021CF9000F007C117D /* Info.plist */,\n',
      '97C147021CF9000F007C117D /* Info.plist */,\n$groupBlock',
    );
  } else {
    content = _replaceMarkedRegion(
      content,
      begin: _pbxGroupMarkers.begin,
      end: _pbxGroupMarkers.end,
      replacement: groupBlock.trimRight(),
    );
    content = content.replaceFirst(
      '${_pbxGroupMarkers.end}				',
      '${_pbxGroupMarkers.end}\n\t\t\t\t',
    );
  }

  content = _ensureMarkedInsert(
    content,
    begin: _pbxResourcesMarkers.begin,
    end: _pbxResourcesMarkers.end,
    replacement: resources.toString(),
    insertAfter:
        '97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n',
  );

  await file.writeAsString(content);
  stdout.writeln('  project.pbxproj AlternateAppIcons updated');
}

String _replaceMarkedRegion(
  String content, {
  required String begin,
  required String end,
  required String replacement,
}) {
  final start = content.indexOf(begin);
  final stop = content.indexOf(end);
  if (start < 0 || stop < 0 || stop < start) {
    return content;
  }
  final endIndex = stop + end.length;
  return content.replaceRange(start, endIndex, replacement.trimRight());
}

String _ensureMarkedInsert(
  String content, {
  required String begin,
  required String end,
  required String replacement,
  required String insertAfter,
}) {
  if (content.contains(begin) && content.contains(end)) {
    return _replaceMarkedRegion(
      content,
      begin: begin,
      end: end,
      replacement: replacement,
    );
  }
  final idx = content.indexOf(insertAfter);
  if (idx < 0) {
    stderr.writeln('Warning: insert point not found for $begin');
    return content;
  }
  return content.replaceRange(
    idx + insertAfter.length,
    idx + insertAfter.length,
    '$replacement\n',
  );
}
