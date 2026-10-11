import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_exceptions.dart';
import '../utils/update_startup_marker.dart';
import 'talker.dart';
import 'windows_portable_update_layout.dart';

/// Windows 绿色包：把新包逐文件覆盖到安装目录（旧文件先改名让位），
/// 拉起新 `s1er.exe` 并确认其成功启动后再退出当前进程。
///
/// 之所以是「文件级」而非「整目录对换」：Windows 上运行中的 exe / DLL
/// **文件**可以改名，但它们所在的**目录**不能被改名。逐文件让位不依赖
/// 外部脚本或辅助进程，也不需要在退出前等待。
///
/// 交接靠「启动标记」握手：旧进程把 [updateStartedMarkerEnv] 指给新进程，
/// 新进程启动早期写入该文件（见 `main()`）；旧进程收到标记才 `exit(0)`，
/// 否则回滚并保留旧版本。因此「新版本起不来」也能被检测并回滚。
///
/// 用户数据在 `%APPDATA%`，不随安装目录一起被替换。
class WindowsPortableUpdater {
  WindowsPortableUpdater({
    String Function()? resolvedExecutable,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String from, String to)? renameFile,
    Future<void> Function(
      String executable,
      String workingDirectory,
      String markerPath,
    )? relaunch,
    void Function(String directory)? setCurrentDirectory,
    void Function(int code)? exitApp,
    this.startTimeout = const Duration(seconds: 20),
  })  : _resolvedExecutable =
            resolvedExecutable ?? (() => Platform.resolvedExecutable),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _renameFile = renameFile ?? _defaultRenameFile,
        _relaunch = relaunch ?? _defaultRelaunch,
        _setCurrentDirectory =
            setCurrentDirectory ?? _defaultSetCurrentDirectory,
        _exitApp = exitApp ?? exit;

  final String Function() _resolvedExecutable;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String from, String to) _renameFile;
  final Future<void> Function(
    String executable,
    String workingDirectory,
    String markerPath,
  ) _relaunch;
  final void Function(String directory) _setCurrentDirectory;
  final void Function(int code) _exitApp;

  /// 等待新进程写入启动标记的最长时间。
  final Duration startTimeout;

  static Future<void> _defaultRenameFile(String from, String to) async {
    await File(from).rename(to);
  }

  static Future<void> _defaultRelaunch(
    String executable,
    String workingDirectory,
    String markerPath,
  ) async {
    await Process.start(
      executable,
      const <String>[],
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
      environment: {updateStartedMarkerEnv: markerPath},
    );
  }

  static void _defaultSetCurrentDirectory(String directory) {
    Directory.current = directory;
  }

  /// 解压 [zipPath]，逐文件覆盖安装目录、确认新版本启动后退出（成功路径不返回）。
  Future<void> applyDownloadedZip(String zipPath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      throw const UpdateCheckException('当前平台不支持覆盖更新');
    }

    final zip = File(zipPath);
    if (!await zip.exists()) {
      throw const UpdateCheckException('更新包不存在');
    }

    final exePath = p.normalize(_resolvedExecutable());
    final installDir = Directory(p.dirname(exePath));
    WindowsPortableUpdateLayout.assertSafeInstallDir(installDir, exePath);

    try {
      await _assertWritable(installDir);
    } on Object {
      throw const UpdateCheckException(
        '当前目录没有写入权限。请把软件解压到普通文件夹（如桌面或文档）后再更新',
      );
    }

    final tempRoot = await _temporaryDirectory();
    await WindowsPortableUpdateLayout.purgeStaleArtifacts(installDir);
    await WindowsPortableUpdateLayout.purgeStaleDownloads(
      Directory(p.join(tempRoot.path, 'updates')),
      keepZipPath: zip.path,
    );

    final staging = Directory(
      p.join(installDir.path, WindowsPortableUpdateLayout.stagingDirName),
    );
    await _deleteQuietly(staging);
    await staging.create(recursive: true);

    List<PathMove> moves;
    try {
      await WindowsPortableUpdateLayout.extractPortableZip(zip, staging);
      final payload = WindowsPortableUpdateLayout.findPayloadDir(staging);
      if (payload == null) {
        throw const UpdateCheckException('更新包里找不到 s1er.exe');
      }
      await WindowsPortableUpdateLayout.assertPeExecutable(
        File(p.join(payload.path, WindowsPortableUpdateLayout.exeName)),
      );
      moves = WindowsPortableUpdateLayout.planFileSwap(
        payloadRoot: payload,
        installDir: installDir,
      );
      if (moves.isEmpty) {
        throw const UpdateCheckException('更新包里没有可安装的文件');
      }
    } on UpdateCheckException {
      await _deleteQuietly(staging);
      rethrow;
    } on Object catch (e, st) {
      await _deleteQuietly(staging);
      talker.handle(e, st, 'Windows portable extract failed');
      throw const UpdateCheckException('无法解析更新包');
    }

    final newExe = p.join(installDir.path, WindowsPortableUpdateLayout.exeName);
    try {
      await _performSwap(
        moves,
        installDir: installDir,
        newExe: newExe,
        tempRoot: tempRoot,
      );
    } on Object {
      await _deleteQuietly(staging);
      rethrow;
    }

    await _deleteQuietly(staging);
    _exitApp(0);
  }

  /// 旧文件让位 → 新文件就位 → 拉起新版本并等其报「已启动」；任一步失败则整体回滚。
  Future<void> _performSwap(
    List<PathMove> moves, {
    required Directory installDir,
    required String newExe,
    required Directory tempRoot,
  }) async {
    // 把当前工作目录移出安装目录，避免它被自己占用。
    try {
      _setCurrentDirectory(tempRoot.path);
    } on Object {
      // 无法改工作目录不致命，继续。
    }

    final marker = File(p.join(tempRoot.path, 's1er-started-$pid.marker'));
    await _deleteQuietlyFile(marker);

    const suffix = WindowsPortableUpdateLayout.oldSuffix;
    final takenAside = <String>[];
    final placed = <String>[];
    final createdDirs = <String>[];

    Future<void> rollback() async {
      for (final target in placed.reversed) {
        try {
          final file = File(target);
          if (await file.exists()) await file.delete();
        } on Object {
          // best-effort
        }
      }
      for (final target in takenAside.reversed) {
        try {
          final old = File('$target$suffix');
          if (await old.exists()) await old.rename(target);
        } on Object {
          // best-effort
        }
      }
      // 删除本次为放置新文件而新建的空目录（深层优先）。
      for (final dir in createdDirs.reversed) {
        try {
          final directory = Directory(dir);
          if (await directory.exists() && await directory.list().isEmpty) {
            await directory.delete();
          }
        } on Object {
          // best-effort
        }
      }
      await _deleteQuietlyFile(marker);
    }

    try {
      for (final move in moves) {
        final dirPath = p.dirname(move.target);
        if (!await Directory(dirPath).exists()) {
          await Directory(dirPath).create(recursive: true);
          createdDirs.add(dirPath);
        }
        final targetFile = File(move.target);
        if (await targetFile.exists()) {
          final aside = '${move.target}$suffix';
          final asideFile = File(aside);
          if (await asideFile.exists()) await asideFile.delete();
          await _renameFile(move.target, aside);
          takenAside.add(move.target);
        }
        await _renameFile(move.source, move.target);
        placed.add(move.target);
      }
      await _relaunch(newExe, installDir.path, marker.path);
      if (!await _awaitStarted(marker)) {
        throw const UpdateCheckException('新版本未能启动');
      }
    } on Object catch (e, st) {
      await rollback();
      talker.handle(e, st, 'Windows portable overlay failed');
      throw const UpdateCheckException(
        '覆盖安装失败：程序文件可能被占用，或新版本无法启动。'
        '请关闭其它 s1er 窗口后重试，或改用浏览器打开 ZIP 手动覆盖',
      );
    }
  }

  /// 轮询等待 [marker] 出现，或到 [startTimeout]。
  Future<bool> _awaitStarted(File marker) async {
    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await marker.exists()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return marker.existsSync();
  }

  static Future<void> _assertWritable(Directory dir) async {
    final probe = File(p.join(dir.path, '.s1er-update-write-test'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
  }

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // best-effort
    }
  }

  static Future<void> _deleteQuietlyFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // best-effort
    }
  }
}
