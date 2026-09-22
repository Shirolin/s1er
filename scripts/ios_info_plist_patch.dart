// scripts/ios_info_plist_patch.dart
//
// Pure (I/O-free) patcher for the iOS icon block in ios/Runner/Info.plist.
// Shared by scripts/sync_app_icons.dart and test/ios_info_plist_test.dart.
//
// History: the previous implementation anchored on the iPad orientations
// array and REBUILT the file tail, discarding everything before the anchor
// (XML header, CFBundle* keys, scene manifest, photo-library usage
// description…), which truncated Info.plist into an invalid file. The patch
// must therefore only ever replace the region between the APP_ICON_ICONS
// markers, and must refuse to touch a file that lacks them.

import 'package:s1er/config/app_icon_catalog.dart';

/// Outer markers wrapping the whole CFBundleIcons …
/// UIApplicationSupportsAlternateIcons block in Info.plist.
const iosPlistIconsMarkers = (
  begin: '<!-- APP_ICON_ICONS_BEGIN -->',
  end: '<!-- APP_ICON_ICONS_END -->',
);

/// Inner markers wrapping only the alternate-icon entries (kept from the
/// original scheme so existing tooling/docs references stay valid).
const iosPlistAlternateMarkers = (
  begin: '<!-- APP_ICON_ALTERNATE_BEGIN -->',
  end: '<!-- APP_ICON_ALTERNATE_END -->',
);

/// Builds the full icon block, markers included, exactly as it must appear
/// inside Info.plist (tab-indented, idempotent when patched repeatedly).
String buildIosPlistIconsBlock() {
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

  return '''
${iosPlistIconsMarkers.begin}
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
			${iosPlistAlternateMarkers.begin}
${alternateEntries.toString().trimRight()}
			${iosPlistAlternateMarkers.end}
		</dict>
	</dict>
	<key>UIApplicationSupportsAlternateIcons</key>
	<true/>
	${iosPlistIconsMarkers.end}''';
}

/// Rewrites only the marker-delimited icon block of [content].
///
/// Throws [StateError] when:
/// - [content] does not look like a complete plist document (truncated file), or
/// - the APP_ICON_ICONS markers are missing / malformed.
///
/// Never rebuilds or drops any content outside the marked region.
String patchIosInfoPlistContent(String content) {
  var normalized = content.replaceAll('\r\n', '\n');
  if (!normalized.startsWith('<?xml') ||
      !normalized.trimRight().endsWith('</plist>')) {
    throw StateError(
      'Info.plist is not a complete plist document '
      '(missing xml header or </plist> tail); refusing to patch.',
    );
  }

  final start = normalized.indexOf(iosPlistIconsMarkers.begin);
  final stop = normalized.indexOf(iosPlistIconsMarkers.end);
  if (start < 0 || stop < 0 || stop < start) {
    throw StateError(
      'Missing ${iosPlistIconsMarkers.begin} / '
      '${iosPlistIconsMarkers.end} markers in Info.plist; '
      'refusing to patch (re-add the markers instead of regenerating).',
    );
  }

  final endIndex = stop + iosPlistIconsMarkers.end.length;
  normalized = normalized.replaceRange(
    start,
    endIndex,
    buildIosPlistIconsBlock(),
  );
  return normalized;
}
