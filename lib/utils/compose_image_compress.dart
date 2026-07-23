import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 上传前图片压缩：默认最长边 [maxLongEdge]（对齐 S1-Next ~2000）。
class ComposeImageCompress {
  ComposeImageCompress._();

  static const int defaultMaxLongEdge = 2000;
  static const int jpegQuality = 85;

  /// [useOriginal] 为 true 时原样返回。
  static Future<({Uint8List bytes, String filename})> maybeCompress({
    required Uint8List bytes,
    required String filename,
    required bool useOriginal,
    int maxLongEdge = defaultMaxLongEdge,
  }) async {
    if (useOriginal || bytes.isEmpty) {
      return (bytes: bytes, filename: filename);
    }
    return compute(
      _compressIsolate,
      _CompressArgs(
        bytes: bytes,
        filename: filename,
        maxLongEdge: maxLongEdge,
      ),
    );
  }
}

class _CompressArgs {
  const _CompressArgs({
    required this.bytes,
    required this.filename,
    required this.maxLongEdge,
  });

  final Uint8List bytes;
  final String filename;
  final int maxLongEdge;
}

({Uint8List bytes, String filename}) _compressIsolate(_CompressArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    return (bytes: args.bytes, filename: args.filename);
  }

  final longEdge =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  img.Image resized = decoded;
  if (longEdge > args.maxLongEdge) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(
        decoded,
        width: args.maxLongEdge,
        interpolation: img.Interpolation.average,
      );
    } else {
      resized = img.copyResize(
        decoded,
        height: args.maxLongEdge,
        interpolation: img.Interpolation.average,
      );
    }
  }

  final lower = args.filename.toLowerCase();
  if (lower.endsWith('.png')) {
    final out = Uint8List.fromList(img.encodePng(resized));
    if (out.length >= args.bytes.length && longEdge <= args.maxLongEdge) {
      return (bytes: args.bytes, filename: args.filename);
    }
    return (bytes: out, filename: args.filename);
  }
  if (lower.endsWith('.gif')) {
    // 动图不压，避免丢帧。
    return (bytes: args.bytes, filename: args.filename);
  }

  final out = Uint8List.fromList(
    img.encodeJpg(resized, quality: ComposeImageCompress.jpegQuality),
  );
  final nextName = lower.endsWith('.jpg') || lower.endsWith('.jpeg')
      ? args.filename
      : _replaceExtension(args.filename, 'jpg');
  if (out.length >= args.bytes.length && longEdge <= args.maxLongEdge) {
    return (bytes: args.bytes, filename: args.filename);
  }
  return (bytes: out, filename: nextName);
}

String _replaceExtension(String filename, String ext) {
  final dot = filename.lastIndexOf('.');
  if (dot <= 0) return '$filename.$ext';
  return '${filename.substring(0, dot)}.$ext';
}
