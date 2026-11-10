import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/config/app_icon_catalog.dart';

void main() {
  group('AppIconCatalog', () {
    test('defaultId is black', () {
      expect(AppIconCatalog.defaultId, 'black');
      expect(AppIconCatalog.defaultVariant.id, 'black');
      expect(AppIconCatalog.defaultVariant.isDefault, isTrue);
    });

    test('normalize falls back for unknown ids', () {
      expect(AppIconCatalog.normalize(null), 'black');
      expect(AppIconCatalog.normalize(''), 'black');
      expect(AppIconCatalog.normalize('nope'), 'black');
      expect(AppIconCatalog.normalize('white'), 'white');
      expect(AppIconCatalog.normalize('black'), 'black');
      expect(AppIconCatalog.normalize('xb2'), 'xb2');
      expect(AppIconCatalog.normalize('md'), 'md');
      expect(AppIconCatalog.normalize('oot'), 'oot');
    });

    test('contains known variants only', () {
      expect(AppIconCatalog.contains('black'), isTrue);
      expect(AppIconCatalog.contains('white'), isTrue);
      expect(AppIconCatalog.contains('xb2'), isTrue);
      expect(AppIconCatalog.contains('md'), isTrue);
      expect(AppIconCatalog.contains('oot'), isTrue);
      expect(AppIconCatalog.contains('seasonal'), isFalse);
    });

    test('alternateVariants excludes default', () {
      expect(
        AppIconCatalog.alternateVariants.map((v) => v.id),
        ['white', 'xb2', 'md', 'oot'],
      );
    });

    test('black stock; white solid-plate; themed masters with 16% safe zone',
        () {
      expect(AppIconCatalog.defaultVariant.androidMipmap, 'ic_launcher');
      expect(AppIconCatalog.defaultVariant.reuseExistingAndroid, isTrue);
      expect(AppIconCatalog.find('white')!.androidMasterAsIcon, isFalse);
      expect(AppIconCatalog.find('xb2')!.androidMasterAsIcon, isTrue);
      expect(AppIconCatalog.find('md')!.androidMasterAsIcon, isTrue);
      expect(AppIconCatalog.find('oot')!.androidMasterAsIcon, isTrue);
      expect(AppIconCatalog.find('md')!.androidMipmap, 'ic_launcher_md');
      expect(AppIconCatalog.find('oot')!.androidMipmap, 'ic_launcher_oot');
      expect(AppIconCatalog.adaptiveInsetPercent, 16);
      expect(
        AppIconCatalog.androidGeneratedVariants.map((v) => v.id),
        ['white', 'xb2', 'md', 'oot'],
      );
    });

    // 生成器原图直接入库过一次：1254²、1.2 MB、满图噪点，APK 体积凭空涨了 1 MB。
    test('branding 方图规格：≤1024px 方图且体积 ≤300 KB', () {
      final paths = <String>{
        for (final v in AppIconCatalog.variants) ...[
          v.previewAsset,
          if (v.masterPath != null) v.masterPath!,
        ],
        AppIconCatalog.adaptiveForegroundPath,
      };

      for (final path in paths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path 不存在');
        final bytes = file.readAsBytesSync();
        final decoded = img.decodePng(bytes);
        expect(decoded, isNotNull, reason: '$path 不是 PNG');
        expect(
          decoded!.width,
          decoded.height,
          reason: '$path 必须是方图（${decoded.width}x${decoded.height}）',
        );
        expect(
          decoded.width,
          lessThanOrEqualTo(1024),
          reason: '$path 分辨率过高（${decoded.width}px）',
        );
        expect(
          bytes.length,
          lessThanOrEqualTo(300 * 1024),
          reason: '$path 体积过大（${(bytes.length / 1024).round()} KB）',
        );
      }
    });
  });
}
