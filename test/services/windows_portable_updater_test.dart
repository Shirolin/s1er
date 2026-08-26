import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:s1er/models/app_exceptions.dart';
import 'package:s1er/services/windows_portable_update_layout.dart';
import 'package:s1er/services/windows_portable_updater.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('s1er_win_upd_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('WindowsPortableUpdater path helpers', () {
    test('resolveSafeExtractPath rejects zip-slip', () {
      final root = tempRoot.path;
      expect(
        WindowsPortableUpdateLayout.resolveSafeExtractPath(root, 's1er.exe'),
        isNotNull,
      );
      expect(
        WindowsPortableUpdateLayout.resolveSafeExtractPath(root, '../evil.exe'),
        isNull,
      );
      expect(
        WindowsPortableUpdateLayout.resolveSafeExtractPath(root, 'a/../../x'),
        isNull,
      );
      expect(
        WindowsPortableUpdateLayout.resolveSafeExtractPath(
          root,
          'C:/Windows/x',
        ),
        isNull,
      );
    });

    test('findPayloadDir uses zip root when s1er.exe is there', () async {
      await File('${tempRoot.path}/s1er.exe').writeAsBytes([0x4D, 0x5A]);
      expect(
        p.normalize(WindowsPortableUpdateLayout.findPayloadDir(tempRoot)!.path),
        tempRoot.path,
      );
    });

    test('findPayloadDir uses nested folder', () async {
      final nested = Directory('${tempRoot.path}/s1er-0.6.0');
      await nested.create();
      await File('${nested.path}/s1er.exe').writeAsBytes([0x4D, 0x5A]);
      expect(
        p.normalize(WindowsPortableUpdateLayout.findPayloadDir(tempRoot)!.path),
        p.normalize(nested.path),
      );
    });
  });

  group('WindowsPortableUpdater extractPortableZip', () {
    test('extracts s1er.exe from a portable zip', () async {
      final zip = File('${tempRoot.path}/app.zip');
      await zip.writeAsBytes(_portableZipBytes());
      final dest = Directory('${tempRoot.path}/out');
      await dest.create();
      await WindowsPortableUpdateLayout.extractPortableZip(zip, dest);
      expect(File('${dest.path}/s1er.exe').existsSync(), isTrue);
      expect(File('${dest.path}/flutter_windows.dll').existsSync(), isTrue);
    });

    test('rejects zip without s1er.exe', () async {
      final zip = File('${tempRoot.path}/bad.zip');
      final archive = Archive()
        ..addFile(ArchiveFile('readme.txt', 4, [1, 2, 3, 4]));
      await zip.writeAsBytes(ZipEncoder().encodeBytes(archive));
      final dest = Directory('${tempRoot.path}/out');
      await dest.create();
      expect(
        () => WindowsPortableUpdateLayout.extractPortableZip(zip, dest),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '更新包里找不到 s1er.exe',
          ),
        ),
      );
    });

    test('rejects zip-slip entries', () async {
      final zip = File('${tempRoot.path}/slip.zip');
      final archive = Archive()..addFile(ArchiveFile('../evil.exe', 2, [1, 2]));
      await zip.writeAsBytes(ZipEncoder().encodeBytes(archive));
      final dest = Directory('${tempRoot.path}/out');
      await dest.create();
      expect(
        () => WindowsPortableUpdateLayout.extractPortableZip(zip, dest),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '更新包包含非法路径',
          ),
        ),
      );
    });
  });

  group('WindowsPortableUpdater applyDownloadedZip', () {
    test('spawns overlay script then exits', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final installDir = Directory('${tempRoot.path}/install');
      await installDir.create();
      await File('${installDir.path}/s1er.exe').writeAsBytes([0x4D, 0x5A]);

      final zip = File('${tempRoot.path}/app.zip');
      await zip.writeAsBytes(_portableZipBytes());

      final spawned = <List<String>>[];
      var exitCode = -1;
      final updater = WindowsPortableUpdater(
        resolvedExecutable: () => p.join(installDir.path, 's1er.exe'),
        currentPid: () => 4242,
        temporaryDirectory: () async => tempRoot,
        spawnDetached: (exe, args) async {
          spawned.add([exe, ...args]);
        },
        exitApp: (code) => exitCode = code,
        spawnSettle: Duration.zero,
      );

      await updater.applyDownloadedZip(zip.path);

      expect(exitCode, 0);
      expect(spawned, isNotEmpty);
      expect(spawned.single.first, 'powershell.exe');
      expect(spawned.single, contains('4242'));
      expect(
        spawned.single.map(p.normalize),
        contains(p.normalize(installDir.path)),
      );
      expect(
        spawned.single.map(p.normalize),
        contains(p.normalize(zip.path)),
      );
    });
  });

  group('WindowsPortableUpdateLayout cleanup helpers', () {
    test('purgeStaleUpdateTemp removes leftover extract dirs and scripts',
        () async {
      await Directory('${tempRoot.path}/s1er-update-extract-1').create();
      await File('${tempRoot.path}/s1er-apply-update-1.ps1').writeAsString('x');
      final keep = File('${tempRoot.path}/updates/s1er-1.0.0.zip');
      await keep.parent.create(recursive: true);
      await keep.writeAsBytes([1, 2, 3, 4]);
      final staleZip = File('${tempRoot.path}/updates/s1er-0.9.0.zip');
      await staleZip.writeAsBytes([5, 6]);

      final removed = await WindowsPortableUpdateLayout.purgeStaleUpdateTemp(
        tempRoot,
        keepZipPath: keep.path,
      );
      expect(removed, greaterThanOrEqualTo(3));
      expect(
        Directory('${tempRoot.path}/s1er-update-extract-1').existsSync(),
        isFalse,
      );
      expect(
        File('${tempRoot.path}/s1er-apply-update-1.ps1').existsSync(),
        isFalse,
      );
      expect(keep.existsSync(), isTrue);
      expect(staleZip.existsSync(), isFalse);
    });

    test('assertPeExecutable accepts MZ and rejects others', () async {
      final ok = File('${tempRoot.path}/s1er.exe');
      await ok.writeAsBytes([0x4D, 0x5A, 0x00]);
      await WindowsPortableUpdateLayout.assertPeExecutable(ok);

      final bad = File('${tempRoot.path}/not.exe');
      await bad.writeAsBytes([0x00, 0x00]);
      expect(
        () => WindowsPortableUpdateLayout.assertPeExecutable(bad),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('apply script swaps directories and always cleans temps', () {
      const script = WindowsPortableUpdateLayout.applyScript;
      expect(script, contains('s1er-bak'));
      expect(script, contains(r'$backupReady'));
      expect(script, contains('exe still locked'));
      expect(script, contains('Restore-S1erBackup'));
      expect(script, contains('Remove-S1erTemp'));
      expect(script, contains('relaunching old exe'));
      expect(script, contains(r'-WorkingDirectory $dst'));
      expect(script, contains(r'$procArgs'));
      expect(script, contains(r'WorkingDirectory = $WorkDir'));
      // rename 失败时不得无条件删安装目录
      expect(
        script.contains(
          r'if ($backupReady -and (Test-Path -LiteralPath $dst))',
        ),
        isTrue,
      );
    });
  });
}

Uint8List _portableZipBytes() {
  final exe = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00]);
  final dll = Uint8List.fromList([1, 2, 3]);
  final archive = Archive()
    ..addFile(ArchiveFile('s1er.exe', exe.length, exe))
    ..addFile(ArchiveFile('flutter_windows.dll', dll.length, dll));
  return ZipEncoder().encodeBytes(archive);
}
