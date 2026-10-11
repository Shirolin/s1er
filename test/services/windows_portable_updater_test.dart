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

  group('WindowsPortableUpdateLayout path helpers', () {
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

    test('planFileSwap maps every payload file onto install dir', () async {
      final payload = Directory('${tempRoot.path}/payload');
      await Directory('${payload.path}/data').create(recursive: true);
      await File('${payload.path}/s1er.exe').writeAsBytes([0x4D, 0x5A]);
      await File('${payload.path}/flutter_windows.dll').writeAsBytes([1, 2]);
      await File('${payload.path}/data/a.txt').writeAsString('x');

      final install = Directory('${tempRoot.path}/install');
      await install.create();

      final moves = WindowsPortableUpdateLayout.planFileSwap(
        payloadRoot: payload,
        installDir: install,
      );
      final targets =
          moves.map((m) => p.relative(m.target, from: install.path)).toSet();
      expect(
        targets,
        {'s1er.exe', 'flutter_windows.dll', p.join('data', 'a.txt')},
      );
    });
  });

  group('WindowsPortableUpdateLayout extractPortableZip', () {
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
    test('swaps files in place, relaunches new exe, then exits', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final installDir = await _seedInstallDir(tempRoot);
      final zip = File('${tempRoot.path}/app.zip');
      await zip.writeAsBytes(_portableZipBytes());

      var exitCode = -1;
      final relaunched = <String>[];
      final updater = WindowsPortableUpdater(
        resolvedExecutable: () => p.join(installDir.path, 's1er.exe'),
        temporaryDirectory: () async => tempRoot,
        relaunch: (exe, wd, marker) async {
          relaunched.add('$exe|$wd');
          // 模拟新进程启动早期写入「已启动」标记。
          await File(marker).writeAsString('99');
        },
        setCurrentDirectory: (_) {},
        exitApp: (code) => exitCode = code,
        startTimeout: const Duration(seconds: 2),
      );

      await updater.applyDownloadedZip(zip.path);

      final installPath = p.normalize(installDir.path);
      expect(exitCode, 0);
      expect(
        relaunched.single,
        '${p.join(installPath, 's1er.exe')}|$installPath',
      );
      // New files are in place.
      expect(
        await File('${installDir.path}/data/a.txt').readAsString(),
        'new',
      );
      expect(File('${installDir.path}/data/new.txt').existsSync(), isTrue);
      // Old files were moved aside, not erased.
      expect(
        File('${installDir.path}/s1er.exe${WindowsPortableUpdateLayout.oldSuffix}')
            .existsSync(),
        isTrue,
      );
      // Staging is cleaned up.
      expect(
        Directory(
          '${installDir.path}/${WindowsPortableUpdateLayout.stagingDirName}',
        ).existsSync(),
        isFalse,
      );
    });

    test('rolls back and keeps the old version when relaunch fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final installDir = await _seedInstallDir(tempRoot);
      final zip = File('${tempRoot.path}/app.zip');
      await zip.writeAsBytes(_portableZipBytes());

      var exitCode = -1;
      final updater = WindowsPortableUpdater(
        resolvedExecutable: () => p.join(installDir.path, 's1er.exe'),
        temporaryDirectory: () async => tempRoot,
        relaunch: (_, __, ___) async => throw StateError('blocked by policy'),
        setCurrentDirectory: (_) {},
        exitApp: (code) => exitCode = code,
        startTimeout: const Duration(seconds: 1),
      );

      await expectLater(
        () => updater.applyDownloadedZip(zip.path),
        throwsA(isA<UpdateCheckException>()),
      );

      expect(exitCode, -1);
      // Old files are back, new payload removed, no leftovers.
      expect(
        await File('${installDir.path}/data/a.txt').readAsString(),
        'old',
      );
      expect(
        await File('${installDir.path}/s1er.exe').readAsBytes(),
        [0x4D, 0x5A, 0x01],
      );
      expect(File('${installDir.path}/data/new.txt').existsSync(), isFalse);
      expect(
        File('${installDir.path}/s1er.exe${WindowsPortableUpdateLayout.oldSuffix}')
            .existsSync(),
        isFalse,
      );
      expect(
        Directory(
          '${installDir.path}/${WindowsPortableUpdateLayout.stagingDirName}',
        ).existsSync(),
        isFalse,
      );
    });

    test('rolls back when the new version never reports started', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final installDir = await _seedInstallDir(tempRoot);
      final zip = File('${tempRoot.path}/app.zip');
      await zip.writeAsBytes(_portableZipBytes());

      var exitCode = -1;
      final updater = WindowsPortableUpdater(
        resolvedExecutable: () => p.join(installDir.path, 's1er.exe'),
        temporaryDirectory: () async => tempRoot,
        // 进程能拉起，但不写标记（起不来 / 秒退）。
        relaunch: (_, __, ___) async {},
        setCurrentDirectory: (_) {},
        exitApp: (code) => exitCode = code,
        startTimeout: const Duration(milliseconds: 300),
      );

      await expectLater(
        () => updater.applyDownloadedZip(zip.path),
        throwsA(isA<UpdateCheckException>()),
      );

      expect(exitCode, -1);
      expect(
        await File('${installDir.path}/data/a.txt').readAsString(),
        'old',
      );
    });
  });

  group('WindowsPortableUpdateLayout cleanup helpers', () {
    test('purgeStaleArtifacts removes .s1erold files and staging dirs',
        () async {
      final install = Directory('${tempRoot.path}/install');
      await install.create();
      await File(
        '${install.path}/s1er.exe${WindowsPortableUpdateLayout.oldSuffix}',
      ).writeAsString('x');
      final staging = Directory(
        '${install.path}/${WindowsPortableUpdateLayout.stagingDirName}',
      );
      await staging.create();
      await File('${staging.path}/s1er.exe').writeAsString('y');
      await File('${install.path}/keep.txt').writeAsString('z');

      final removed =
          await WindowsPortableUpdateLayout.purgeStaleArtifacts(install);

      expect(removed, greaterThanOrEqualTo(2));
      expect(
        File('${install.path}/s1er.exe${WindowsPortableUpdateLayout.oldSuffix}')
            .existsSync(),
        isFalse,
      );
      expect(staging.existsSync(), isFalse);
      expect(File('${install.path}/keep.txt').existsSync(), isTrue);
    });

    test('purgeStaleDownloads keeps the current zip only', () async {
      final dir = Directory('${tempRoot.path}/updates');
      await dir.create();
      final keep = File('${dir.path}/s1er-2.0.0.zip');
      await keep.writeAsBytes([1]);
      final stale = File('${dir.path}/s1er-1.0.0.zip');
      await stale.writeAsBytes([2]);
      final other = File('${dir.path}/notes.txt');
      await other.writeAsString('x');

      final removed = await WindowsPortableUpdateLayout.purgeStaleDownloads(
        dir,
        keepZipPath: keep.path,
      );

      expect(removed, 1);
      expect(keep.existsSync(), isTrue);
      expect(stale.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
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
  });
}

Future<Directory> _seedInstallDir(Directory tempRoot) async {
  final installDir = Directory('${tempRoot.path}/install');
  await Directory('${installDir.path}/data').create(recursive: true);
  await File('${installDir.path}/s1er.exe').writeAsBytes([0x4D, 0x5A, 0x01]);
  await File('${installDir.path}/flutter_windows.dll').writeAsBytes([1, 1]);
  await File('${installDir.path}/data/a.txt').writeAsString('old');
  return installDir;
}

Uint8List _portableZipBytes() {
  final exe = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00]);
  final dll = Uint8List.fromList([2, 2, 2]);
  final aTxt = Uint8List.fromList('new'.codeUnits);
  final newTxt = Uint8List.fromList('added'.codeUnits);
  final archive = Archive()
    ..addFile(ArchiveFile('s1er.exe', exe.length, exe))
    ..addFile(ArchiveFile('flutter_windows.dll', dll.length, dll))
    ..addFile(ArchiveFile('data/a.txt', aTxt.length, aTxt))
    ..addFile(ArchiveFile('data/new.txt', newTxt.length, newTxt));
  return ZipEncoder().encodeBytes(archive);
}
