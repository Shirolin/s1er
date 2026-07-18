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
    });

    test('contains known variants only', () {
      expect(AppIconCatalog.contains('black'), isTrue);
      expect(AppIconCatalog.contains('white'), isTrue);
      expect(AppIconCatalog.contains('seasonal'), isFalse);
    });

    test('alternateVariants excludes default', () {
      expect(
        AppIconCatalog.alternateVariants.map((v) => v.id),
        ['white'],
      );
    });

    test('black reuses stock ic_launcher; white is generated', () {
      expect(AppIconCatalog.defaultVariant.androidMipmap, 'ic_launcher');
      expect(AppIconCatalog.defaultVariant.reuseExistingAndroid, isTrue);
      expect(
        AppIconCatalog.find('white')!.androidMipmap,
        'ic_launcher_white',
      );
      expect(
        AppIconCatalog.androidGeneratedVariants.map((v) => v.id),
        ['white'],
      );
    });
  });
}
