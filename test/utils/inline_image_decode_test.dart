import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/utils/inline_image_decode.dart';

void main() {
  group('inlineDecodeWidthPx', () {
    test('scales layout width by device pixel ratio', () {
      expect(inlineDecodeWidthPx(300, 2), 600);
    });

    test('clamps to configured min and max', () {
      expect(
        inlineDecodeWidthPx(50, 1),
        S1Constants.inlineImageDecodeMinPx,
      );
      expect(
        inlineDecodeWidthPx(2000, 3),
        S1Constants.inlineImageDecodeMaxPx,
      );
    });
  });
}
