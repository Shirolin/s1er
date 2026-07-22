import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'talker.dart';

/// 运行时自定义字体管理服务（仅 Native 平台有效）。
abstract final class FontImportService {
  static const _kFontDir = 'fonts';
  static const _kFontFile = 'custom.ttf';
  static const kFontFamily = 'S1CustomFont';

  static Future<File?> get _fontFile async {
    if (ServicesBinding.instance == null) return null;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final fontDir = Directory(p.join(supportDir.path, _kFontDir));
      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }
      return File(p.join(fontDir.path, _kFontFile));
    } on Object catch (e, st) {
      talker.handle(e, st, 'FontImportService: 获取字体文件路径失败');
      return null;
    }
  }

  /// 从选中的 [file] 导入字体：写入本地持久化文件并动态加载到引擎。
  /// 返回原本的文件名用于 UI 展示。
  static Future<String> importFont(XFile file) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台暂不支持导入自定义字体');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('字体文件内容为空');
    }

    final targetFile = await _fontFile;
    if (targetFile == null) {
      throw Exception('无法获取应用存储目录');
    }
    await targetFile.writeAsBytes(bytes, flush: true);

    await _loadFontToEngine(bytes);
    return file.name;
  }

  /// 冷启动时恢复注册已保存的字体。
  static Future<bool> tryRestoreFont() async {
    if (kIsWeb) return false;
    if (ServicesBinding.instance == null) return false;
    try {
      final file = await _fontFile;
      if (file == null || !await file.exists()) return false;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return false;
      await _loadFontToEngine(bytes);
      return true;
    } on Object catch (e, st) {
      talker.handle(e, st, 'FontImportService: 恢复自定义字体失败');
      return false;
    }
  }

  /// 删除本地保存的自定义字体文件。
  static Future<void> removeCustomFont() async {
    if (kIsWeb) return;
    if (ServicesBinding.instance == null) return;
    try {
      final file = await _fontFile;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } on Object catch (e, st) {
      talker.handle(e, st, 'FontImportService: 删除自定义字体文件失败');
    }
  }

  static Future<void> _loadFontToEngine(Uint8List bytes) async {
    final fontData = ByteData.sublistView(bytes);
    final fontLoader = FontLoader(kFontFamily);
    fontLoader.addFont(Future.value(fontData));
    await fontLoader.load();
  }
}
