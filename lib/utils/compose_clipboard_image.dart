import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pasteboard/pasteboard.dart';

/// 从系统剪贴板读取图片字节。Web / 失败时返回 `null`（降级为文本粘贴）。
Future<Uint8List?> readComposeClipboardImage() async {
  if (kIsWeb) return null;
  try {
    return await Pasteboard.image;
  } on Object {
    return null;
  }
}

/// 粘贴图片的默认文件名（剪贴板图多为 PNG）。
String composeClipboardImageFilename([DateTime? now]) {
  final t = now ?? DateTime.now();
  final stamp =
      '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}_'
      '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}${t.second.toString().padLeft(2, '0')}';
  return 'paste_$stamp.png';
}
