import 'package:flutter/foundation.dart';

/// One raw RGBA bitmap strip (same width as siblings when stitching).
class ShareRgbaStrip {
  const ShareRgbaStrip({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Truncates [strip] to at most [maxPhysicalHeight] physical rows.
ShareRgbaStrip cropStripToPhysicalHeight(
  ShareRgbaStrip strip,
  int maxPhysicalHeight,
) {
  if (maxPhysicalHeight <= 0) {
    throw ArgumentError('maxPhysicalHeight must be positive');
  }
  if (strip.height <= maxPhysicalHeight) {
    return strip;
  }
  final byteCount = strip.width * maxPhysicalHeight * 4;
  if (strip.bytes.length < byteCount) {
    throw ArgumentError(
      'RGBA buffer too short: ${strip.bytes.length} < $byteCount',
    );
  }
  return ShareRgbaStrip(
    bytes: Uint8List.sublistView(strip.bytes, 0, byteCount),
    width: strip.width,
    height: maxPhysicalHeight,
  );
}

class _StitchArgs {
  const _StitchArgs(this.strips);

  final List<ShareRgbaStrip> strips;
}

ShareRgbaStrip stitchRgbaVertically(List<ShareRgbaStrip> strips) {
  if (strips.isEmpty) {
    throw ArgumentError('Cannot stitch an empty strip list');
  }
  final width = strips.first.width;
  if (width <= 0) {
    throw ArgumentError('Strip width must be positive');
  }

  var totalHeight = 0;
  for (final strip in strips) {
    if (strip.width != width) {
      throw ArgumentError(
        'Strip width mismatch: expected $width, got ${strip.width}',
      );
    }
    if (strip.height <= 0) {
      throw ArgumentError('Strip height must be positive');
    }
    final expected = strip.width * strip.height * 4;
    if (strip.bytes.length < expected) {
      throw ArgumentError(
        'RGBA buffer too short: ${strip.bytes.length} < $expected',
      );
    }
    totalHeight += strip.height;
  }

  final out = Uint8List(width * totalHeight * 4);
  var offset = 0;
  for (final strip in strips) {
    final byteCount = strip.width * strip.height * 4;
    out.setRange(offset, offset + byteCount, strip.bytes);
    offset += byteCount;
  }

  return ShareRgbaStrip(bytes: out, width: width, height: totalHeight);
}

ShareRgbaStrip _stitchIsolate(_StitchArgs args) =>
    stitchRgbaVertically(args.strips);

/// Vertical RGBA stitch; large buffers run in a background isolate.
Future<ShareRgbaStrip> stitchRgbaVerticallyAsync(
  List<ShareRgbaStrip> strips,
) {
  final approxBytes = strips.fold<int>(0, (sum, s) => sum + s.bytes.length);
  if (approxBytes < 256 * 1024) {
    return Future.value(stitchRgbaVertically(strips));
  }
  return compute(_stitchIsolate, _StitchArgs(strips));
}

/// Incrementally composes strips into one RGBA bitmap (peak RAM ≈ 1× output).
class VerticalRgbaComposer {
  VerticalRgbaComposer({int? initialCapacityHeight})
      : _initialCapacityHeight = initialCapacityHeight ?? 0,
        _buffer = Uint8List(0);

  factory VerticalRgbaComposer.fromEstimatedPhysicalSize({
    required int estimatedPhysicalHeight,
  }) {
    if (estimatedPhysicalHeight <= 0) {
      throw ArgumentError('estimatedPhysicalHeight must be positive');
    }
    return VerticalRgbaComposer(
      initialCapacityHeight: estimatedPhysicalHeight,
    );
  }

  final int _initialCapacityHeight;
  Uint8List _buffer;
  int? _width;
  int _height = 0;
  int _offset = 0;

  int? get width => _width;
  int get totalHeight => _height;

  void appendStrip(ShareRgbaStrip strip) {
    if (strip.height <= 0) {
      throw ArgumentError('Strip height must be positive');
    }
    final expected = strip.width * strip.height * 4;
    if (strip.bytes.length < expected) {
      throw ArgumentError(
        'RGBA buffer too short: ${strip.bytes.length} < $expected',
      );
    }

    if (_width == null) {
      _width = strip.width;
      final capacityRows =
          _initialCapacityHeight > 0 ? _initialCapacityHeight : strip.height;
      _buffer = Uint8List(strip.width * capacityRows * 4);
    } else if (strip.width != _width) {
      throw ArgumentError(
        'Strip width mismatch: expected $_width, got ${strip.width}',
      );
    }

    _ensureCapacity(_offset + expected);
    _buffer.setRange(_offset, _offset + expected, strip.bytes);
    _offset += expected;
    _height += strip.height;
  }

  void _ensureCapacity(int needed) {
    if (needed <= _buffer.length) return;
    var newSize = _buffer.isEmpty ? needed : _buffer.length;
    while (newSize < needed) {
      newSize *= 2;
    }
    final next = Uint8List(newSize);
    if (_offset > 0) {
      next.setRange(0, _offset, _buffer);
    }
    _buffer = next;
  }

  ShareRgbaStrip build() {
    final width = _width;
    if (width == null || _height <= 0) {
      throw StateError('VerticalRgbaComposer has no strips');
    }
    return ShareRgbaStrip(
      bytes: Uint8List.sublistView(_buffer, 0, _offset),
      width: width,
      height: _height,
    );
  }
}
