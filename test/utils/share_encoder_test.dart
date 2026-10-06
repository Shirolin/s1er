import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/share_image_format.dart';
import 'package:s1er/utils/share_encoder.dart';
import 'package:s1er/utils/share_image_stitch.dart';

bool _isPng(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

bool _isWebp(Uint8List bytes) =>
    bytes.length >= 12 &&
    bytes[0] == 0x52 && // R
    bytes[1] == 0x49 && // I
    bytes[2] == 0x46 && // F
    bytes[3] == 0x46 && // F
    bytes[8] == 0x57 && // W
    bytes[9] == 0x45 && // E
    bytes[10] == 0x42 && // B
    bytes[11] == 0x50; // P

ShareRgbaStrip _solidStrip() {
  // 2x2 opaque red.
  final rgba = Uint8List.fromList([
    255, 0, 0, 255, 255, 0, 0, 255, //
    255, 0, 0, 255, 255, 0, 0, 255,
  ]);
  return ShareRgbaStrip(bytes: rgba, width: 2, height: 2);
}

void main() {
  // 说明：`flutter test` 下 native（ironpress）编码不可用，utils 层会捕获
  // StateError 返回 null，因此这里正好覆盖「native 失败 → PNG 降级」链路。
  const bg = Color(0xFFFFFFFF);

  test('png format encodes to PNG bytes', () async {
    const encoder = ShareEncoder(format: ShareImageFormat.png, background: bg);
    final encoded = await encoder.encodeStrip(_solidStrip());
    expect(encoded.format, ShareImageFormat.png);
    expect(_isPng(encoded.bytes), isTrue);
  });

  test(
      'jpeg format encodes to JPEG, or falls back to PNG when native is '
      'unavailable', () async {
    const encoder = ShareEncoder(format: ShareImageFormat.jpeg, background: bg);
    final encoded = await encoder.encodeStrip(_solidStrip());
    // 依 native（ironpress）可用性：成功则 JPEG，失败则降级 PNG。
    if (encoded.format == ShareImageFormat.jpeg) {
      expect(_isJpeg(encoded.bytes), isTrue);
    } else {
      expect(encoded.format, ShareImageFormat.png);
      expect(_isPng(encoded.bytes), isTrue);
    }
    expect(encoded.bytes, isNotEmpty);
  });

  test(
      'webp format encodes to WebP, or falls back to PNG when native is '
      'unavailable', () async {
    const encoder = ShareEncoder(format: ShareImageFormat.webp, background: bg);
    final encoded = await encoder.encodeStrip(_solidStrip());
    if (encoded.format == ShareImageFormat.webp) {
      expect(_isWebp(encoded.bytes), isTrue);
    } else {
      expect(encoded.format, ShareImageFormat.png);
      expect(_isPng(encoded.bytes), isTrue);
    }
    expect(encoded.bytes, isNotEmpty);
  });

  test('EncodedShareImage exposes extension and mimeType from its format', () {
    final encoded = EncodedShareImage(Uint8List(0), ShareImageFormat.png);
    expect(encoded.extension, ShareImageFormat.png.extension);
    expect(encoded.mimeType, ShareImageFormat.png.mimeType);
  });
}
