import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'talker.dart';

/// 导入失败时可直接展示给用户的错误（[toString] 不带类名前缀）。
class FontImportException implements Exception {
  const FontImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 冷启动恢复自定义字体的结果。
enum FontRestoreResult {
  /// 已注册到引擎。
  restored,

  /// 没有保存过字体文件（或平台不支持）。
  missing,

  /// 文件存在但内容不合法 / 引擎拒绝；文件已被删除。
  invalid,

  /// 读取失败（IO）；文件与设置都保留，下次启动重试。
  unreadable,
}

/// 运行时自定义字体管理服务（仅 Native 平台有效）。
abstract final class FontImportService {
  static const _kFontDir = 'fonts';
  static const _kFontFile = 'custom.ttf';

  /// sfnt 容器最小长度（表目录 12 字节起）。
  static const _kMinFontBytes = 12;

  /// 体积上限：常见中文字体 5–20 MB，40 MB 已能覆盖且拦住误选的大文件。
  static const _kMaxFontBytes = 40 * 1024 * 1024;

  /// 当前已注册到引擎的族名；null 表示未使用自定义字体。
  ///
  /// 族名由文件内容派生，换字体即换族名——同名族重复注册多个 typeface 时
  /// 引擎的匹配顺序不可控，会出现「导入新字体却不生效」。
  static String? get activeFamily => _activeFamily;
  static String? _activeFamily;

  static Future<File?> get _fontFile async {
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

  /// 从选中的 [file] 导入字体：校验 → 写入本地持久化文件 → 动态加载到引擎。
  /// 返回原本的文件名用于 UI 展示。
  static Future<String> importFont(XFile file) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台暂不支持导入自定义字体');
    }
    final bytes = await file.readAsBytes();
    validateBytes(bytes);

    final targetFile = await _fontFile;
    if (targetFile == null) {
      throw const FontImportException('无法获取应用存储目录');
    }
    // 先写临时文件、激活成功后再改名：加载失败的字体不能留在盘上，
    // 否则此后每次冷启动都会在恢复阶段失败。
    final temp = File('${targetFile.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    final previousFamily = _activeFamily;
    try {
      await _activate(bytes);
      await temp.rename(targetFile.path);
    } on Object {
      // 激活成功但落盘失败：本次会话已切到新族，回滚它，避免主题指向
      // 一个没存下来的字体（重启后必然回退）。
      _activeFamily = previousFamily;
      await _deleteQuietly(temp);
      rethrow;
    }
    return file.name;
  }

  /// 冷启动时恢复注册已保存的字体。
  ///
  /// 必须在首帧构建主题**之前** await 完成：主题按 [activeFamily] 选族，
  /// 而 `FontLoader.load()` 不会触发重建，晚加载会让首帧回退到系统字体。
  static Future<FontRestoreResult> tryRestoreFont() async {
    if (kIsWeb) return FontRestoreResult.missing;
    final file = await _fontFile;
    if (file == null || !await file.exists()) {
      return FontRestoreResult.missing;
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object catch (e, st) {
      // IO 问题（被占用、权限、磁盘错误）不代表字体坏了：保留文件与设置，
      // 下次启动重试。上次这里返回 false，调用方会误清掉用户设置。
      talker.handle(e, st, 'FontImportService: 读取字体文件失败，保留待下次重试');
      return FontRestoreResult.unreadable;
    }

    try {
      validateBytes(bytes);
      await _activate(bytes);
      return FontRestoreResult.restored;
    } on Object catch (e, st) {
      // 内容无效，或头部合法但引擎拒绝：删掉，避免每次冷启动重复失败。
      talker.handle(e, st, 'FontImportService: 字体文件无效，已删除');
      await _deleteQuietly(file);
      return FontRestoreResult.invalid;
    }
  }

  /// 删除本地保存的自定义字体文件。
  static Future<void> removeCustomFont() async {
    if (kIsWeb) return;
    _activeFamily = null;
    try {
      final file = await _fontFile;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } on Object catch (e, st) {
      talker.handle(e, st, 'FontImportService: 删除自定义字体文件失败');
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object catch (e, st) {
      talker.handle(e, st, 'FontImportService: 删除字体文件失败');
    }
  }

  /// 校验 sfnt 容器头与体积；失败抛 [FontImportException]。
  @visibleForTesting
  static void validateBytes(Uint8List bytes) {
    if (bytes.length < _kMinFontBytes) {
      throw const FontImportException('字体文件太小，不是有效的 TTF / OTF');
    }
    if (bytes.length > _kMaxFontBytes) {
      throw const FontImportException(
        '字体文件超过 ${_kMaxFontBytes ~/ (1024 * 1024)} MB，请换用更小的字体',
      );
    }
    // 0x00010000 = TrueType outlines，'OTTO' = CFF outlines，'true' = Apple。
    // 字体集合（'ttcf'）与 Web 字体（'wOFF'）不支持。
    final magic = ByteData.sublistView(bytes, 0, 4).getUint32(0);
    const accepted = {0x00010000, 0x4F54544F, 0x74727565};
    if (!accepted.contains(magic)) {
      throw const FontImportException('不是有效的字体文件（仅支持 .ttf / .otf）');
    }
  }

  /// 由内容派生的族名（同一文件恒定，换文件即变）。
  @visibleForTesting
  static String familyFor(Uint8List bytes) =>
      'S1CustomFont_${_contentTag(bytes)}';

  static Future<void> _activate(Uint8List bytes) async {
    final family = familyFor(bytes);
    if (_activeFamily == family) return;
    final fontData = ByteData.sublistView(bytes);
    final fontLoader = FontLoader(family);
    fontLoader.addFont(Future.value(fontData));
    await fontLoader.load();
    _activeFamily = family;
  }

  /// FNV-1a over 全文件内容 + 长度：族名必须随内容变化，否则换字体可能命中
  /// [activeFamily] 的同族提前返回。
  ///
  /// 仅在 native 使用（Web 不支持导入），因此 32 位乘法在 JS 上的精度差异无影响。
  /// 字体上限 40 MB，导入与冷启动各算一次，耗时远小于读文件本身。
  static String _contentTag(Uint8List bytes) {
    var hash = 0x811c9dc5;
    void mix(int byte) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }

    final length = bytes.length;
    for (var shift = 0; shift < 32; shift += 8) {
      mix((length >> shift) & 0xFF);
    }
    for (var i = 0; i < length; i++) {
      mix(bytes[i]);
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
