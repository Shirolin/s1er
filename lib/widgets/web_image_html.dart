// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web 端通过 Blob URL 触发浏览器下载（跨域直链的 download 属性无效）
Future<void> downloadImageWeb(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: objectUrl)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }
}
