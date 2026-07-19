import 'package:flutter_test/flutter_test.dart';
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
    });

    test('contains known variants only', () {
      expect(AppIconCatalog.contains('black'), isTrue);
      expect(AppIconCatalog.contains('white'), isTrue);
      expect(AppIconCatalog.contains('xb2'), isTrue);
      expect(AppIconCatalog.contains('seasonal'), isFalse);
    });

    test('alternateVariants excludes default', () {
      expect(
        AppIconCatalog.alternateVariants.map((v) => v.id),
        ['white', 'xb2'],
      );
    });

    test('black stock; white solid-plate; xb2 master with 16% safe zone', () {
      expect(AppIconCatalog.defaultVariant.androidMipmap, 'ic_launcher');
      expect(AppIconCatalog.defaultVariant.reuseExistingAndroid, isTrue);
      expect(AppIconCatalog.find('white')!.androidMasterAsIcon, isFalse);
      expect(AppIconCatalog.find('xb2')!.androidMasterAsIcon, isTrue);
      expect(AppIconCatalog.adaptiveInsetPercent, 16);
      expect(
        AppIconCatalog.androidGeneratedVariants.map((v) => v.id),
        ['white', 'xb2'],
      );
    });
  });
}
