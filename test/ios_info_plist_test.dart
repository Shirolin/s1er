// 回归测试：iOS Info.plist 完整性 + sync_app_icons 纯函数补丁行为。
//
// 背景：scripts/sync_app_icons.dart 旧版 _patchIosInfoPlist 曾以 iPad 方向锚
// 点重建文件尾，把 Info.plist 截断成非法文件（丢失 CFBundle* / 相册权限 /
// Scene manifest / 启动屏等全部键）。此测试确保：
//   1. 仓库中的 Info.plist 始终是完整、关键键齐全且不重复的合法 plist；
//   2. 补丁纯函数只替换标记区间、幂等、且对截断/缺标记文件拒绝写入。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/app_icon_catalog.dart';

import '../scripts/ios_info_plist_patch.dart';

void main() {
  final plistFile = File('ios/Runner/Info.plist');

  group('ios/Runner/Info.plist 结构', () {
    test('文件存在且是完整 plist 文档', () {
      expect(plistFile.existsSync(), isTrue, reason: 'Info.plist 缺失');
      final content = plistFile.readAsStringSync();
      expect(content, startsWith('<?xml'));
      expect(content.trimRight(), endsWith('</plist>'));
      expect(content, contains('<plist version="1.0">'));
      expect(content, contains('<dict>'));
    });

    test('关键键存在（截断回归会同时丢掉它们）', () {
      final content = plistFile.readAsStringSync();
      const requiredKeys = [
        'CFBundleDisplayName',
        'CFBundleExecutable',
        'CFBundleIdentifier',
        'CFBundleShortVersionString',
        'CFBundleVersion',
        'NSPhotoLibraryAddUsageDescription',
        'UIApplicationSceneManifest',
        'UILaunchStoryboardName',
        'UIMainStoryboardFile',
        'UISupportedInterfaceOrientations',
        'UISupportedInterfaceOrientations~ipad',
        'CADisableMinimumFrameDurationOnPhone',
        'LSRequiresIPhoneOS',
        'CFBundleIcons',
        'UIApplicationSupportsAlternateIcons',
      ];
      for (final key in requiredKeys) {
        expect(
          content,
          contains('<key>$key</key>'),
          reason: '缺少 <key>$key</key>',
        );
      }
    });

    test('关键键恰好出现一次（防重复块回归）', () {
      final content = plistFile.readAsStringSync();
      for (final key in [
        'CFBundleIcons',
        'CFBundleAlternateIcons',
        'UIApplicationSceneManifest',
        'NSPhotoLibraryAddUsageDescription',
        'UILaunchStoryboardName',
      ]) {
        final count = '<key>$key</key>'.allMatches(content).length;
        expect(count, 1, reason: '<key>$key</key> 应恰好出现 1 次，实际 $count');
      }
    });

    test('交替图标标记与 AppIconCatalog 同步', () {
      final content = plistFile.readAsStringSync();
      expect(content, contains(iosPlistIconsMarkers.begin));
      expect(content, contains(iosPlistIconsMarkers.end));
      for (final variant in AppIconCatalog.alternateVariants) {
        expect(
          content,
          contains('<string>AppIcon-${variant.id}</string>'),
          reason: '缺少交替图标 ${variant.id}',
        );
      }
    });
  });

  group('patchIosInfoPlistContent', () {
    test('对仓库当前文件幂等（跑两次结果一致）', () {
      final content = plistFile.readAsStringSync();
      final once = patchIosInfoPlistContent(content);
      final twice = patchIosInfoPlistContent(once);
      expect(once, content, reason: '补丁输出应与仓库文件完全一致');
      expect(twice, once, reason: '补丁必须幂等');
    });

    test('保留标记区间之外的全部内容', () {
      final content = plistFile.readAsStringSync();
      final patched = patchIosInfoPlistContent(content);
      // 关键键在补丁后仍完好。
      expect(patched, contains('<key>NSPhotoLibraryAddUsageDescription</key>'));
      expect(patched, contains('<key>UIApplicationSceneManifest</key>'));
      expect(patched, startsWith('<?xml'));
      expect(patched.trimRight(), endsWith('</plist>'));
    });

    test('拒绝处理截断的 plist（缺 XML 头 / 缺 </plist>）', () {
      // 模拟旧版脚本造成的截断形态：文件直接以 iPad 方向键开头。
      const truncated = '''
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
	<key>CFBundleIcons</key>
</dict>
</plist>
''';
      expect(
        () => patchIosInfoPlistContent(truncated),
        throwsA(isA<StateError>()),
        reason: '截断文件必须拒绝补丁，而不是被进一步破坏',
      );

      const missingTail = '<?xml version="1.0" encoding="UTF-8"?>\n<dict>';
      expect(
        () => patchIosInfoPlistContent(missingTail),
        throwsA(isA<StateError>()),
      );
    });

    test('拒绝处理缺标记的文件', () {
      const noMarkers = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>S1er</string>
</dict>
</plist>
''';
      expect(
        () => patchIosInfoPlistContent(noMarkers),
        throwsA(isA<StateError>()),
        reason: '标记缺失时应报错，让维护者手工恢复标记而不是重建文件',
      );
    });

    test('生成的标记块包含全部交替图标', () {
      final block = buildIosPlistIconsBlock();
      expect(block, startsWith(iosPlistIconsMarkers.begin));
      expect(block.trimRight(), endsWith(iosPlistIconsMarkers.end));
      expect(block, contains('<key>CFBundlePrimaryIcon</key>'));
      for (final variant in AppIconCatalog.alternateVariants) {
        expect(block, contains('<key>${variant.id}</key>'));
      }
    });
  });
}
