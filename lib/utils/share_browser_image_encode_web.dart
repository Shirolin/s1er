// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Encode opaque/pre-composited RGBA via the browser's native canvas codec.
///
/// Much faster than pure-Dart [image] encoders on Flutter Web. Supports
/// `image/jpeg` and `image/webp` (when the browser accepts the MIME type).
Future<Uint8List?> encodeRgbaWithBrowser({
  required Uint8List rgbaBytes,
  required int width,
  required int height,
  required String mimeType,
  double quality = 0.85,
}) async {
  if (rgbaBytes.length < width * height * 4) return null;

  final canvas = html.CanvasElement(width: width, height: height);
  final ctx = canvas.context2D;
  final imageData = ctx.createImageData(width, height);
  imageData.data.setRange(0, rgbaBytes.length, rgbaBytes);
  ctx.putImageData(imageData, 0, 0);

  final html.Blob blob;
  try {
    blob = await canvas.toBlob(mimeType, quality);
  } on Object {
    return null;
  }

  final reader = html.FileReader();
  final done = Completer<Uint8List?>();
  reader.onError.listen((_) {
    if (!done.isCompleted) done.complete(null);
  });
  reader.onLoadEnd.listen((_) {
    if (done.isCompleted) return;
    final result = reader.result;
    if (result is ByteBuffer) {
      done.complete(Uint8List.view(result));
    } else {
      done.complete(null);
    }
  });
  reader.readAsArrayBuffer(blob);
  return done.future;
}
