import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/emoticon_catalog.dart';

void main() {
  group('EmoticonCatalog', () {
    test('exposes six packs matching S1-Next order and sizes', () {
      expect(EmoticonCatalog.packs.map((p) => p.entityPrefix).toList(), [
        'f',
        'c',
        'a',
        'd',
        'g',
        'b',
      ]);
      expect(EmoticonCatalog.packs.map((p) => p.count).toList(), [
        275,
        430,
        30,
        44,
        74,
        37,
      ]);
    });

    test('builds entity and network urls', () {
      final face = EmoticonCatalog.packs.first;
      final item = EmoticonCatalog.itemsFor(face).first;
      expect(item.entity, '[f:001]');
      expect(
        item.pngUrl,
        'https://static.stage1st.com/image/smiley/face2017/001.png',
      );
      expect(
        item.gifUrl,
        'https://static.stage1st.com/image/smiley/face2017/001.gif',
      );
    });

    test('findByCode accepts bracketed and raw forms', () {
      expect(EmoticonCatalog.findByCode('[c:010]')?.entity, '[c:010]');
      expect(EmoticonCatalog.findByCode('a:3')?.entity, '[a:003]');
      expect(EmoticonCatalog.findByCode('[f:999]'), isNull);
      expect(EmoticonCatalog.findByCode('[x:001]'), isNull);
    });
  });
}
