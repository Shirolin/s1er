import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/app_exceptions.dart';

/// 覆盖更新时一个文件从 `source`（暂存）搬到 `target`（安装目录）的路径规划。
class PathMove {
  const PathMove({required this.source, required this.target});

  final String source;
  final String target;
}

/// Windows 绿色包 ZIP 的解压、目录识别，以及「逐文件热替换」的路径规划。
///
/// Windows 上运行中的 exe / DLL **文件**可以改名（所在**目录**不行），
/// 因此覆盖更新走文件级对换：把旧文件改名让位、把新文件就位，无需外部
/// 脚本或辅助进程。见 `docs/release/README.md` 的「Windows 绿色包」。
abstract final class WindowsPortableUpdateLayout {
  static const exeName = 's1er.exe';

  /// 解压暂存目录名（位于安装目录内，随安装目录一起被清理）。
  static const stagingDirName = '.s1er-staging';

  /// 被让位旧文件的后缀。
  static const oldSuffix = '.s1erold';

  /// 解压绿色包；拒绝 zip-slip（`../`）条目。
  static Future<void> extractPortableZip(File zip, Directory dest) async {
    final bytes = await zip.readAsBytes();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const UpdateCheckException('无法解析更新包');
    }

    var wroteExe = false;
    for (final entry in archive) {
      final destPath = resolveSafeExtractPath(dest.path, entry.name);
      if (destPath == null) {
        throw const UpdateCheckException('更新包包含非法路径');
      }
      if (entry.isDirectory || entry.name.endsWith('/')) {
        await Directory(destPath).create(recursive: true);
        continue;
      }
      await Directory(p.dirname(destPath)).create(recursive: true);
      await File(destPath).writeAsBytes(entry.content, flush: true);
      if (p.basename(destPath).toLowerCase() == exeName) {
        wroteExe = true;
      }
    }
    if (!wroteExe) {
      throw const UpdateCheckException('更新包里找不到 s1er.exe');
    }
  }

  /// ZIP 根目录或子目录里的 `s1er.exe`。
  static Directory? findPayloadDir(Directory extracted) {
    final direct = File(p.join(extracted.path, exeName));
    if (direct.existsSync()) return extracted;

    final dirs =
        extracted.listSync().whereType<Directory>().toList(growable: false);
    for (final dir in dirs) {
      if (File(p.join(dir.path, exeName)).existsSync()) return dir;
    }
    return null;
  }

  static String? resolveSafeExtractPath(String extractRoot, String entryName) {
    final cleaned = entryName.replaceAll('\\', '/').trim();
    if (cleaned.isEmpty || cleaned.startsWith('/') || cleaned.contains(':')) {
      return null;
    }
    final parts = <String>[];
    for (final part in cleaned.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') return null;
      parts.add(part);
    }
    if (parts.isEmpty) {
      return p.normalize(extractRoot);
    }
    final dest = p.normalize(p.join(extractRoot, p.joinAll(parts)));
    final root = p.normalize(extractRoot);
    if (dest == root) return dest;
    if (!p.isWithin(root, dest)) return null;
    return dest;
  }

  static void assertSafeInstallDir(Directory installDir, String exePath) {
    final dir = p.normalize(installDir.path);
    final lower = dir.replaceAll('/', '\\').toLowerCase();
    if (!File(p.join(dir, exeName)).existsSync()) {
      throw const UpdateCheckException('找不到当前安装目录里的 s1er.exe');
    }
    if (lower.contains('\\build\\windows\\') && lower.contains('\\runner\\')) {
      throw const UpdateCheckException('开发构建目录不支持覆盖更新');
    }
    final root = p.rootPrefix(dir).replaceAll('/', '\\').toLowerCase();
    if (lower == root) {
      throw const UpdateCheckException('安装目录无效');
    }
    if (p.basename(exePath).toLowerCase() != exeName) {
      throw const UpdateCheckException('当前进程不是 s1er.exe');
    }
  }

  /// 新包里的 `s1er.exe` 必须是 PE（`MZ`），避免把 HTML 错误页当安装包。
  static Future<void> assertPeExecutable(File exe) async {
    if (!await exe.exists()) {
      throw const UpdateCheckException('更新包里找不到 s1er.exe');
    }
    final raf = await exe.open();
    try {
      final magic = await raf.read(2);
      if (magic.length < 2 || magic[0] != 0x4D || magic[1] != 0x5A) {
        throw const UpdateCheckException('更新包中的 s1er.exe 无效');
      }
    } finally {
      await raf.close();
    }
  }

  /// 规划把 [payloadRoot] 下每个文件搬到 [installDir] 的对应位置。
  ///
  /// 只做纯路径计算（不落盘），便于单测；实际对换时目标已存在则先让位。
  static List<PathMove> planFileSwap({
    required Directory payloadRoot,
    required Directory installDir,
  }) {
    final root = p.normalize(payloadRoot.path);
    final install = p.normalize(installDir.path);
    final moves = <PathMove>[];
    for (final entity
        in payloadRoot.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.relative(p.normalize(entity.path), from: root);
      if (rel.isEmpty || rel.startsWith('..')) continue;
      final target = p.normalize(p.join(install, rel));
      if (!p.isWithin(install, target)) continue;
      moves.add(PathMove(source: entity.path, target: target));
    }
    return moves;
  }

  /// 清掉上次更新残留：安装目录内 `*.s1erold` 文件与 `.s1er-staging*` 目录。
  ///
  /// 正在运行的旧版 exe / 被占用的文件删不掉，属预期，直接跳过。
  static Future<int> purgeStaleArtifacts(Directory installDir) async {
    if (!await installDir.exists()) return 0;
    var removed = 0;
    final entities =
        await installDir.list(recursive: true, followLinks: false).toList();
    // 先删文件（避免目录删除被内含文件拖累），再删目录。
    for (final entity in entities) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith(oldSuffix)) continue;
      try {
        await entity.delete();
        removed++;
      } on Object {
        // 可能仍被占用，跳过。
      }
    }
    for (final entity in entities) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name != stagingDirName && !name.startsWith('$stagingDirName-')) {
        continue;
      }
      try {
        await entity.delete(recursive: true);
        removed++;
      } on Object {
        // 跳过。
      }
    }
    return removed;
  }

  /// 清掉下载目录里除 [keepZipPath] 外的旧 `s1er-*.zip`，避免临时目录堆积。
  static Future<int> purgeStaleDownloads(
    Directory dir, {
    String? keepZipPath,
  }) async {
    if (!await dir.exists()) return 0;
    final keep = keepZipPath == null ? null : p.normalize(keepZipPath);
    var removed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path).toLowerCase();
      if (!name.startsWith('s1er-') || !name.endsWith('.zip')) continue;
      if (keep != null && p.normalize(entity.path) == keep) continue;
      try {
        await entity.delete();
        removed++;
      } on Object {
        // skip locked
      }
    }
    return removed;
  }
}
