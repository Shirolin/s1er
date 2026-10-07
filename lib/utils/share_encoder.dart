import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/share_image_format.dart';
import 'share_image_stitch.dart';
import 'share_native_image_encoder.dart';
import 'share_rgba_encoder.dart';
import 'share_rgba_flatten.dart';
import 'share_browser_image_encode_stub.dart'
    if (dart.library.html) 'share_browser_image_encode_web.dart'
    as browser_encode;

/// Encoded share-card bytes plus the format that actually landed in [bytes]
/// (may differ from the user preference when native encode falls back).
class EncodedShareImage {
  const EncodedShareImage(this.bytes, this.format);

  final Uint8List bytes;
  final ShareImageFormat format;

  String get extension => format.extension;
  String get mimeType => format.mimeType;
}

/// 分享卡编码：按 [format] 分派 PNG / JPEG / WebP，并在 native 编码失败时
/// 逐级降级回 PNG。
///
/// 纯编排：只依赖 `dart:ui` 与 encoding utils，不依赖 widget / Riverpod /
/// Theme。背景色由调用方从主题解析后经 [background] 传入（用于把半透明
/// 像素压平到不透明底，供 JPEG / WebP 使用）。
class ShareEncoder {
  const ShareEncoder({required this.format, required this.background});

  final ShareImageFormat format;

  /// 已被压平用的不透明背景色（调用方从 `Theme` 解析）。
  final ui.Color background;

  // 有意保留两处按 format 的分派：image 与 strip 的输入形状不同，
  // 强行合表只会把重复从 switch 搬到 map。
  /// 编码由 `RenderRepaintBoundary.toImage` 得到的整图。
  Future<EncodedShareImage> encodeImage(ui.Image image) {
    return switch (format) {
      ShareImageFormat.png => _encodePng(image),
      ShareImageFormat.jpeg => _encodeJpeg(image),
      ShareImageFormat.webp => _encodeWebp(image),
    };
  }

  /// 编码拼接后的 RGBA 长图。
  Future<EncodedShareImage> encodeStrip(ShareRgbaStrip strip) {
    return switch (format) {
      ShareImageFormat.png => _encodePngFromRgba(strip),
      ShareImageFormat.jpeg => _encodeJpegFromRgba(strip),
      ShareImageFormat.webp => _encodeWebpFromRgba(strip),
    };
  }

  Future<EncodedShareImage> _encodePngFromRgba(ShareRgbaStrip strip) async {
    final png = await encodePngFromRgbaStrip(strip);
    return _finalizePng(png);
  }

  Future<EncodedShareImage> _encodeJpegFromRgba(ShareRgbaStrip strip) async {
    return _encodeWithCodec(
      opaqueOf: () => _opaqueRgbaFromStrip(strip),
      pngOf: () => encodePngFromRgbaStrip(strip),
      mimeType: 'image/jpeg',
      format: ShareImageFormat.jpeg,
      encodeNative: encodeShareJpegFromPng,
    );
  }

  Future<EncodedShareImage> _encodeWebpFromRgba(ShareRgbaStrip strip) async {
    return _encodeWithCodec(
      opaqueOf: () => _opaqueRgbaFromStrip(strip),
      pngOf: () => encodePngFromRgbaStrip(strip),
      mimeType: 'image/webp',
      format: ShareImageFormat.webp,
      encodeNative: encodeShareWebpFromPng,
    );
  }

  /// Web 先试浏览器编码，native 先把 PNG 转目标格式；失败都回退到 PNG。
  ///
  /// [opaqueOf] / [pngOf] 惰性求值：Web 命中浏览器编码时不算 PNG，native
  /// 不算 opaque（与迁移前 `post_share_service` 的求值顺序一致）。
  Future<EncodedShareImage> _encodeWithCodec({
    required Future<({Uint8List bytes, int width, int height})> Function()
        opaqueOf,
    required Future<Uint8List> Function() pngOf,
    required String mimeType,
    required ShareImageFormat format,
    required Future<Uint8List?> Function(Uint8List png) encodeNative,
  }) async {
    if (kIsWeb) {
      final opaque = await opaqueOf();
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: mimeType,
        quality: 0.85,
      );
      if (browserBytes != null) {
        return EncodedShareImage(browserBytes, format);
      }
      return EncodedShareImage(await pngOf(), ShareImageFormat.png);
    }

    final png = await pngOf();
    final encoded = await encodeNative(png);
    if (encoded != null) {
      return EncodedShareImage(encoded, format);
    }
    return _finalizePng(png);
  }

  /// PNG 落盘收尾：Web 直接返回（浏览器侧无需优化），native 试 oxipng 优化。
  Future<EncodedShareImage> _finalizePng(Uint8List png) async {
    if (kIsWeb) {
      return EncodedShareImage(png, ShareImageFormat.png);
    }
    final optimized = await encodeSharePngOptimized(png);
    return EncodedShareImage(optimized ?? png, ShareImageFormat.png);
  }

  Future<EncodedShareImage> _encodePng(ui.Image image) async {
    final skiaPng = await _encodePngSkia(image);
    return _finalizePng(skiaPng);
  }

  Future<Uint8List> _encodePngSkia(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<EncodedShareImage> _encodeJpeg(ui.Image image) async {
    return _encodeWithCodec(
      opaqueOf: () => _opaqueRgbaFromImage(image),
      pngOf: () => _encodePngSkia(image),
      mimeType: 'image/jpeg',
      format: ShareImageFormat.jpeg,
      encodeNative: encodeShareJpegFromPng,
    );
  }

  Future<EncodedShareImage> _encodeWebp(ui.Image image) async {
    return _encodeWithCodec(
      opaqueOf: () => _opaqueRgbaFromImage(image),
      pngOf: () => _encodePngSkia(image),
      mimeType: 'image/webp',
      format: ShareImageFormat.webp,
      encodeNative: encodeShareWebpFromPng,
    );
  }

  Future<({Uint8List bytes, int width, int height})> _opaqueRgbaFromStrip(
    ShareRgbaStrip strip,
  ) async {
    final expected = strip.width * strip.height * 4;
    final rgbaBytes = strip.bytes.length == expected
        ? strip.bytes
        : Uint8List.sublistView(strip.bytes, 0, expected);
    return _flattenRgba(
      rgbaBytes: rgbaBytes,
      width: strip.width,
      height: strip.height,
    );
  }

  Future<({Uint8List bytes, int width, int height})> _opaqueRgbaFromImage(
    ui.Image image,
  ) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final raw = byteData!;
    final rgbaBytes = raw.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );
    return _flattenRgba(
      rgbaBytes: rgbaBytes,
      width: image.width,
      height: image.height,
    );
  }

  Future<({Uint8List bytes, int width, int height})> _flattenRgba({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) async {
    final opaque = await flattenRgbaOntoOpaqueRgbaAsync(
      rgba: rgbaBytes,
      width: width,
      height: height,
      bgR: (background.r * 255).round(),
      bgG: (background.g * 255).round(),
      bgB: (background.b * 255).round(),
    );
    return (bytes: opaque, width: width, height: height);
  }
}
