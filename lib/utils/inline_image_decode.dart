import 'package:flutter/painting.dart';

import '../config/constants.dart';

/// Target decode width in physical pixels for inline post images.
int inlineDecodeWidthPx(double layoutWidth, double devicePixelRatio) {
  final raw = (layoutWidth * devicePixelRatio).round();
  return raw.clamp(
    S1Constants.inlineImageDecodeMinPx,
    S1Constants.inlineImageDecodeMaxPx,
  );
}

/// Wraps [source] so Flutter decodes at most [targetWidthPx] wide for inline display.
ImageProvider inlineImageProvider(ImageProvider source, int targetWidthPx) {
  return ResizeImage(
    source,
    width: targetWidthPx,
    allowUpscaling: false,
  );
}
