// ignore_for_file: unawaited_futures

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

  /// 编码由 `RenderRepaintBoundary.toImage` 得到的整图。
  Future<EncodedShareImage> encodeImage(ui.Image image) {
    switch (format) {
      case ShareImageFormat.png:
        return _encodePng(image);
      case ShareImageFormat.jpeg:
        return _encodeJpeg(image);
      case ShareImageFormat.webp:
        return _encodeWebp(image);
    }
  }

  /// 编码拼接后的 RGBA 长图。
  Future<EncodedShareImage> encodeStrip(ShareRgbaStrip strip) {
    switch (format) {
      case ShareImageFormat.png:
        return _encodePngFromRgba(strip);
      case ShareImageFormat.jpeg:
        return _encodeJpegFromRgba(strip);
      case ShareImageFormat.webp:
        return _encodeWebpFromRgba(strip);
    }
  }

  Future<EncodedShareImage> _encodePngFromRgba(ShareRgbaStrip strip) async {
    final png = await encodePngFromRgbaStrip(strip);
    if (kIsWeb) {
      return EncodedShareImage(png, ShareImageFormat.png);
    }

    final optimized = await encodeSharePngOptimized(png);
    return EncodedShareImage(optimized ?? png, ShareImageFormat.png);
  }

  Future<EncodedShareImage> _encodeJpegFromRgba(ShareRgbaStrip strip) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromStrip(strip);
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: 'image/jpeg',
        quality: 0.85,
      );
      if (browserBytes != null) {
        return EncodedShareImage(browserBytes, ShareImageFormat.jpeg);
      }
      final png = await encodePngFromRgbaStrip(strip);
      return EncodedShareImage(png, ShareImageFormat.png);
    }

    final png = await encodePngFromRgbaStrip(strip);
    final jpeg = await encodeShareJpegFromPng(png);
    if (jpeg != null) {
      return EncodedShareImage(jpeg, ShareImageFormat.jpeg);
    }

    final optimized = await encodeSharePngOptimized(png);
    return EncodedShareImage(optimized ?? png, ShareImageFormat.png);
  }

  Future<EncodedShareImage> _encodeWebpFromRgba(ShareRgbaStrip strip) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromStrip(strip);
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: 'image/webp',
        quality: 0.85,
      );
      if (browserBytes != null) {
        return EncodedShareImage(browserBytes, ShareImageFormat.webp);
      }
      final png = await encodePngFromRgbaStrip(strip);
      return EncodedShareImage(png, ShareImageFormat.png);
    }

    final png = await encodePngFromRgbaStrip(strip);
    final webp = await encodeShareWebpFromPng(png);
    if (webp != null) {
      return EncodedShareImage(webp, ShareImageFormat.webp);
    }

    final optimized = await encodeSharePngOptimized(png);
    return EncodedShareImage(optimized ?? png, ShareImageFormat.png);
  }

  Future<EncodedShareImage> _encodePng(ui.Image image) async {
    final skiaPng = await _encodePngSkia(image);
    if (kIsWeb) {
      return EncodedShareImage(skiaPng, ShareImageFormat.png);
    }

    final optimized = await encodeSharePngOptimized(skiaPng);
    return EncodedShareImage(optimized ?? skiaPng, ShareImageFormat.png);
  }

  Future<Uint8List> _encodePngSkia(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<EncodedShareImage> _encodeJpeg(ui.Image image) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromImage(image);
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: 'image/jpeg',
        quality: 0.85,
      );
      if (browserBytes != null) {
        return EncodedShareImage(browserBytes, ShareImageFormat.jpeg);
      }
      return EncodedShareImage(
        await _encodePngSkia(image),
        ShareImageFormat.png,
      );
    }

    final skiaPng = await _encodePngSkia(image);
    final jpeg = await encodeShareJpegFromPng(skiaPng);
    if (jpeg != null) {
      return EncodedShareImage(jpeg, ShareImageFormat.jpeg);
    }

    final optimized = await encodeSharePngOptimized(skiaPng);
    return EncodedShareImage(optimized ?? skiaPng, ShareImageFormat.png);
  }

  Future<EncodedShareImage> _encodeWebp(ui.Image image) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromImage(image);
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: 'image/webp',
        quality: 0.85,
      );
      if (browserBytes != null) {
        return EncodedShareImage(browserBytes, ShareImageFormat.webp);
      }
      return EncodedShareImage(
        await _encodePngSkia(image),
        ShareImageFormat.png,
      );
    }

    final skiaPng = await _encodePngSkia(image);
    final webp = await encodeShareWebpFromPng(skiaPng);
    if (webp != null) {
      return EncodedShareImage(webp, ShareImageFormat.webp);
    }

    final optimized = await encodeSharePngOptimized(skiaPng);
    return EncodedShareImage(optimized ?? skiaPng, ShareImageFormat.png);
  }

  Future<({Uint8List bytes, int width, int height})> _opaqueRgbaFromStrip(
    ShareRgbaStrip strip,
  ) async {
    final bgR = (background.r * 255).round();
    final bgG = (background.g * 255).round();
    final bgB = (background.b * 255).round();
    final expected = strip.width * strip.height * 4;
    final rgbaBytes = strip.bytes.length == expected
        ? strip.bytes
        : Uint8List.sublistView(strip.bytes, 0, expected);

    final opaque = await flattenRgbaOntoOpaqueRgbaAsync(
      rgba: rgbaBytes,
      width: strip.width,
      height: strip.height,
      bgR: bgR,
      bgG: bgG,
      bgB: bgB,
    );
    return (bytes: opaque, width: strip.width, height: strip.height);
  }

  Future<({Uint8List bytes, int width, int height})> _opaqueRgbaFromImage(
    ui.Image image,
  ) async {
    final width = image.width;
    final height = image.height;
    final bgR = (background.r * 255).round();
    final bgG = (background.g * 255).round();
    final bgB = (background.b * 255).round();

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final raw = byteData!;
    final rgbaBytes = raw.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );

    final opaque = await flattenRgbaOntoOpaqueRgbaAsync(
      rgba: rgbaBytes,
      width: width,
      height: height,
      bgR: bgR,
      bgG: bgG,
      bgB: bgB,
    );
    return (bytes: opaque, width: width, height: height);
  }
}
