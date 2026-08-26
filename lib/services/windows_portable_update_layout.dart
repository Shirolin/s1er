import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/app_exceptions.dart';

/// 绿色包 ZIP 的解压与目录识别（不含进程退出 / 覆盖脚本）。
abstract final class WindowsPortableUpdateLayout {
  static const exeName = 's1er.exe';

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

  /// 清掉上次失败/杀进程留下的解压目录和覆盖脚本，避免临时目录堆积。
  static Future<int> purgeStaleUpdateTemp(
    Directory tempRoot, {
    String? keepZipPath,
  }) async {
    var removed = 0;
    if (!await tempRoot.exists()) return 0;

    await for (final entity in tempRoot.list(followLinks: false)) {
      final name = p.basename(entity.path);
      try {
        if (entity is Directory && name.startsWith('s1er-update-extract-')) {
          await entity.delete(recursive: true);
          removed++;
          continue;
        }
        if (entity is File &&
            name.startsWith('s1er-apply-update-') &&
            name.toLowerCase().endsWith('.ps1')) {
          await entity.delete();
          removed++;
        }
      } on Object {
        // 正在跑的覆盖脚本可能锁着文件，跳过。
      }
    }

    if (keepZipPath != null) {
      final keep = p.normalize(keepZipPath);
      final zipDir = Directory(p.dirname(keep));
      if (await zipDir.exists()) {
        await for (final entity in zipDir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path).toLowerCase();
          if (!name.startsWith('s1er-') || !name.endsWith('.zip')) continue;
          if (p.normalize(entity.path) == keep) continue;
          try {
            await entity.delete();
            removed++;
          } on Object {
            // skip locked
          }
        }
      }
    }
    return removed;
  }

  /// 等进程退出后整目录对换；失败则回滚并拉起旧程序，最后清临时文件。
  static const applyScript = r'''
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 's1er-update.log'
function Write-S1erLog([string]$Message) {
  Add-Content -LiteralPath $log -Value (("[{0}] {1}" -f (Get-Date -Format s), $Message))
}
$appPid = [int]$args[0]
$src = $args[1]
$dst = $args[2]
$oldExe = $args[3]
$zip = $args[4]
$self = $MyInvocation.MyCommand.Path
$dstName = Split-Path -Leaf $dst
$backup = $dst + '.s1er-bak'
$backupReady = $false

function Start-S1erExe([string]$Path, [string]$WorkDir) {
  if (Test-Path -LiteralPath $Path) {
    $procArgs = @{ FilePath = $Path }
    if ($WorkDir -and (Test-Path -LiteralPath $WorkDir)) {
      $procArgs.WorkingDirectory = $WorkDir
    }
    Start-Process @procArgs
  }
}
function Remove-S1erTemp {
  if ($src -and (Test-Path -LiteralPath $src)) {
    Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction SilentlyContinue
    $parent = Split-Path -Parent $src
    $leaf = Split-Path -Leaf $parent
    if ($leaf -like 's1er-update-extract-*') {
      Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  if ($zip -and (Test-Path -LiteralPath $zip)) {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
  }
  if ($self -and (Test-Path -LiteralPath $self)) {
    Remove-Item -LiteralPath $self -Force -ErrorAction SilentlyContinue
  }
}
function Restore-S1erBackup {
  if (-not (Test-Path -LiteralPath $dst) -and (Test-Path -LiteralPath $backup)) {
    Rename-Item -LiteralPath $backup -NewName $dstName
  }
}

Write-S1erLog 'waiting for process to exit'
for ($i = 0; $i -lt 90; $i++) {
  if (-not (Get-Process -Id $appPid -ErrorAction SilentlyContinue)) { break }
  Start-Sleep -Seconds 1
}
if (Get-Process -Id $appPid -ErrorAction SilentlyContinue) {
  Write-S1erLog 'timeout waiting for process; relaunching old exe'
  Start-S1erExe $oldExe $dst
  Remove-S1erTemp
  exit 1
}

$exeUnlocked = $false
for ($i = 0; $i -lt 30; $i++) {
  try {
    $fs = [System.IO.File]::Open($oldExe, 'Open', 'ReadWrite', 'None')
    $fs.Close()
    $exeUnlocked = $true
    break
  } catch {
    Start-Sleep -Seconds 1
  }
}
if (-not $exeUnlocked) {
  Write-S1erLog 'exe still locked; relaunching old exe'
  Start-S1erExe $oldExe $dst
  Remove-S1erTemp
  exit 1
}

try {
  if (Test-Path -LiteralPath $backup) {
    Remove-Item -LiteralPath $backup -Recurse -Force
  }
  Rename-Item -LiteralPath $dst -NewName (Split-Path -Leaf $backup)
  $backupReady = $true
  Move-Item -LiteralPath $src -Destination $dst
} catch {
  Write-S1erLog ("swap failed: " + $_)
  if ($backupReady -and (Test-Path -LiteralPath $dst)) {
    Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue
    Restore-S1erBackup
    Start-S1erExe (Join-Path $dst 's1er.exe') $dst
  } else {
    Start-S1erExe $oldExe $dst
  }
  Remove-S1erTemp
  exit 1
}

$newExe = Join-Path $dst 's1er.exe'
if (-not (Test-Path -LiteralPath $newExe)) {
  Write-S1erLog 'new exe missing; restoring backup'
  if ($backupReady -and (Test-Path -LiteralPath $dst)) {
    Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue
  }
  Restore-S1erBackup
  Start-S1erExe (Join-Path $dst 's1er.exe') $dst
  Remove-S1erTemp
  exit 1
}

Start-Process -FilePath $newExe -WorkingDirectory $dst
if (Test-Path -LiteralPath $backup) {
  Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
}
Write-S1erLog 'update applied'
Remove-S1erTemp
exit 0
''';
}
