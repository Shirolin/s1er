import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/emoticon_catalog.dart';
import 'package:s1er/utils/platform_image_url.dart';

void main() {
  tearDown(() {
    EmoticonCatalog.clearManifest();
    EmoticonCatalog.resetPacksToFallback();
  });

  group('EmoticonCatalog', () {
    test('exposes six packs with expected order and sizes', () {
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

    test('applyManifest sets exact ext and asset path', () {
      EmoticonCatalog.applyManifest({
        'f:001': 'face2017/001.gif',
        'c:010': 'carton2017/010.png',
      });
      final face = EmoticonCatalog.findByCode('[f:001]')!;
      expect(face.resolvedExt, 'gif');
      expect(face.assetPath, 'assets/emoticons/face2017/001.gif');
      expect(
        face.networkUrl,
        'https://static.stage1st.com/image/smiley/face2017/001.gif',
      );

      final carton = EmoticonCatalog.findByCode('c:10')!;
      expect(carton.resolvedExt, 'png');
      expect(carton.relativePath, 'carton2017/010.png');
    });

    test('fromSmileyUrl parses CDN paths', () {
      final item = EmoticonCatalog.fromSmileyUrl(
        'https://static.stage1st.com/image/smiley/face2017/004.gif',
      );
      expect(item?.entity, '[f:004]');
      expect(item?.resolvedExt, 'gif');
    });

    test('findByCode rejects unknown codes', () {
      expect(EmoticonCatalog.findByCode('[f:999]'), isNull);
      expect(EmoticonCatalog.findByCode('[x:001]'), isNull);
    });
  });

  group('platformImageUrl', () {
    test('rewrites on web', () {
      final url = platformImageUrl(
        'https://static.stage1st.com/image/smiley/face2017/001.png',
        isWeb: true,
      );
      expect(url, contains('/img-proxy?url='));
      expect(url, contains(Uri.encodeComponent('https://static.stage1st.com')));
    });

    test('keeps original off web', () {
      const original =
          'https://static.stage1st.com/image/smiley/face2017/001.png';
      expect(platformImageUrl(original, isWeb: false), original);
    });
  });
}
