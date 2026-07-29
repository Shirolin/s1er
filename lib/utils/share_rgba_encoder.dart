import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'share_capture_helpers.dart';
import 'share_image_stitch.dart';

class _RgbaEncodeArgs {
  const _RgbaEncodeArgs({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class _RgbaScaleArgs {
  const _RgbaScaleArgs({
    required this.bytes,
    required this.width,
    required this.height,
    required this.targetWidth,
    required this.targetHeight,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int targetWidth;
  final int targetHeight;
}

void _ensureRgbaLength(ShareRgbaStrip strip) {
  final expected = strip.width * strip.height * 4;
  if (strip.bytes.length < expected) {
    throw ArgumentError(
      'RGBA buffer too short: ${strip.bytes.length} < $expected',
    );
  }
}

Uint8List _rgbaBytesView(ShareRgbaStrip strip) {
  _ensureRgbaLength(strip);
  final expected = strip.width * strip.height * 4;
  if (strip.bytes.length == expected &&
      strip.bytes.offsetInBytes == 0 &&
      strip.bytes.lengthInBytes == expected) {
    return strip.bytes;
  }
  return Uint8List.sublistView(strip.bytes, 0, expected);
}

img.Image _imageFromRgbaStrip(ShareRgbaStrip strip) {
  final bytes = _rgbaBytesView(strip);
  return img.Image.fromBytes(
    width: strip.width,
    height: strip.height,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
}

Uint8List _encodePngFromRgbaIsolate(_RgbaEncodeArgs args) {
  final image = img.Image.fromBytes(
    width: args.width,
    height: args.height,
    bytes: args.bytes.buffer,
    bytesOffset: args.bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(image));
}

ShareRgbaStrip _scaleRgbaStripIsolate(_RgbaScaleArgs args) {
  final image = img.Image.fromBytes(
    width: args.width,
    height: args.height,
    bytes: args.bytes.buffer,
    bytesOffset: args.bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final resized = img.copyResize(
    image,
    width: args.targetWidth,
    height: args.targetHeight,
    interpolation: img.Interpolation.average,
  );
  return ShareRgbaStrip(
    bytes: Uint8List.fromList(
      resized.getBytes(order: img.ChannelOrder.rgba),
    ),
    width: resized.width,
    height: resized.height,
  );
}

/// CPU PNG encode — bypasses GPU texture height limits on very tall stitches.
Future<Uint8List> encodePngFromRgbaStrip(ShareRgbaStrip strip) async {
  final bytes = Uint8List.fromList(_rgbaBytesView(strip));
  final args = _RgbaEncodeArgs(
    bytes: bytes,
    width: strip.width,
    height: strip.height,
  );
  if (bytes.length < 256 * 1024) {
    return _encodePngFromRgbaIsolate(args);
  }
  return compute(_encodePngFromRgbaIsolate, args);
}

/// Downscale [strip] to fit [maxPixels] while preserving aspect ratio.
ShareRgbaStrip scaleRgbaStripToFitPixels(
  ShareRgbaStrip strip, {
  required int maxPixels,
}) {
  final target = scaleDimensionsToFitPixels(
    width: strip.width,
    height: strip.height,
    maxPixels: maxPixels,
  );
  if (target.width == strip.width && target.height == strip.height) {
    return strip;
  }

  final resized = img.copyResize(
    _imageFromRgbaStrip(strip),
    width: target.width,
    height: target.height,
    interpolation: img.Interpolation.average,
  );
  return ShareRgbaStrip(
    bytes: Uint8List.fromList(
      resized.getBytes(order: img.ChannelOrder.rgba),
    ),
    width: resized.width,
    height: resized.height,
  );
}

/// Isolate-backed variant of [scaleRgbaStripToFitPixels] for large buffers.
Future<ShareRgbaStrip> scaleRgbaStripToFitPixelsAsync(
  ShareRgbaStrip strip, {
  required int maxPixels,
}) async {
  final target = scaleDimensionsToFitPixels(
    width: strip.width,
    height: strip.height,
    maxPixels: maxPixels,
  );
  if (target.width == strip.width && target.height == strip.height) {
    return strip;
  }

  final bytes = Uint8List.fromList(_rgbaBytesView(strip));
  final args = _RgbaScaleArgs(
    bytes: bytes,
    width: strip.width,
    height: strip.height,
    targetWidth: target.width,
    targetHeight: target.height,
  );
  if (bytes.length < 256 * 1024) {
    return _scaleRgbaStripIsolate(args);
  }
  return compute(_scaleRgbaStripIsolate, args);
}
