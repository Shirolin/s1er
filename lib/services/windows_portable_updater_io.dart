import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_exceptions.dart';
import 'talker.dart';
import 'windows_portable_update_layout.dart';

/// Windows 绿色包：解压到临时目录，退出后用脚本整目录对换并重启。
///
/// 用户数据在 `%APPDATA%`，不会随安装目录一起被覆盖。
class WindowsPortableUpdater {
  WindowsPortableUpdater({
    String Function()? resolvedExecutable,
    int Function()? currentPid,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String executable, List<String> arguments)?
        spawnDetached,
    void Function(int code)? exitApp,
    this.spawnSettle = const Duration(milliseconds: 400),
  })  : _resolvedExecutable =
            resolvedExecutable ?? (() => Platform.resolvedExecutable),
        _currentPid = currentPid ?? (() => pid),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _spawnDetached = spawnDetached ?? _defaultSpawnDetached,
        _exitApp = exitApp ?? exit;

  final String Function() _resolvedExecutable;
  final int Function() _currentPid;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String executable, List<String> arguments)
      _spawnDetached;
  final void Function(int code) _exitApp;
  final Duration spawnSettle;

  static Future<void> _defaultSpawnDetached(
    String executable,
    List<String> arguments,
  ) async {
    await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
    );
  }

  /// 解压 [zipPath]，拉起覆盖脚本后退出当前进程（成功路径通常不返回）。
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
    await WindowsPortableUpdateLayout.purgeStaleUpdateTemp(
      tempRoot,
      keepZipPath: zip.path,
    );

    final extractDir = Directory(
      p.join(tempRoot.path, 's1er-update-extract-${_currentPid()}'),
    );
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    try {
      await WindowsPortableUpdateLayout.extractPortableZip(zip, extractDir);
      final payload = WindowsPortableUpdateLayout.findPayloadDir(extractDir);
      if (payload == null) {
        throw const UpdateCheckException('更新包里找不到 s1er.exe');
      }
      await WindowsPortableUpdateLayout.assertPeExecutable(
        File(p.join(payload.path, WindowsPortableUpdateLayout.exeName)),
      );

      final script = File(
        p.join(tempRoot.path, 's1er-apply-update-${_currentPid()}.ps1'),
      );
      await script.writeAsBytes(
        _utf8BomScript(WindowsPortableUpdateLayout.applyScript),
        flush: true,
      );

      await _spawnDetached(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
          '${_currentPid()}',
          payload.path,
          installDir.path,
          p.join(installDir.path, WindowsPortableUpdateLayout.exeName),
          zip.path,
        ],
      );
    } on UpdateCheckException {
      await _deleteQuietly(extractDir);
      await _deleteFileQuietly(
        File(p.join(tempRoot.path, 's1er-apply-update-${_currentPid()}.ps1')),
      );
      rethrow;
    } on Object catch (e, st) {
      await _deleteQuietly(extractDir);
      await _deleteFileQuietly(
        File(p.join(tempRoot.path, 's1er-apply-update-${_currentPid()}.ps1')),
      );
      talker.handle(e, st, 'Windows portable overlay failed');
      throw const UpdateCheckException('无法开始覆盖安装');
    }

    // 给脱离进程的 PowerShell 一点启动时间，再退出以免脚本还没挂上 PID。
    await Future<void>.delayed(spawnSettle);
    _exitApp(0);
  }

  static Uint8List _utf8BomScript(String source) {
    final encoded = utf8.encode(source);
    return Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...encoded]);
  }

  static Future<void> _assertWritable(Directory dir) async {
    final probe = File(
      p.join(dir.path, '.s1er-update-write-test'),
    );
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

  static Future<void> _deleteFileQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // best-effort
    }
  }
}
