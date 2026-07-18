// scripts/compress_screenshots.dart
// Run with: dart run scripts/compress_screenshots.dart
//
// 遍历 site/assets/screenshots 文件夹中的 PNG 文件，
// 调用系统 ffmpeg 将其转换为质量为 80 的 WebP 文件，并删除原 PNG。

import 'dart:io';

void main() async {
  final targetDir = Directory('site/assets/screenshots');
  if (!targetDir.existsSync()) {
    stderr.writeln('Error: Directory ${targetDir.path} does not exist.');
    exitCode = 1;
    return;
  }

  // 检查 ffmpeg 是否可用
  try {
    final result = await Process.run('ffmpeg', ['-version']);
    if (result.exitCode != 0) {
      stderr.writeln('Error: ffmpeg returned exit code ${result.exitCode}.');
      exitCode = 1;
      return;
    }
  } catch (e) {
    stderr.writeln('Error: ffmpeg is not available in the PATH. $e');
    exitCode = 1;
    return;
  }

  stdout.writeln('Scanning ${targetDir.path} for PNG files...');
  final files = targetDir.listSync();
  final pngFiles = files
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList();

  if (pngFiles.isEmpty) {
    stdout.writeln('No PNG files found in ${targetDir.path}.');
    return;
  }

  stdout.writeln('Found ${pngFiles.length} PNG file(s) to process.');
  var totalOldSize = 0;
  var totalNewSize = 0;

  for (final file in pngFiles) {
    final oldPath = file.path;
    final newPath = oldPath.substring(0, oldPath.length - 4) + '.webp';
    final oldSize = file.lengthSync();
    totalOldSize += oldSize;

    stdout.write(
        'Compressing ${file.uri.pathSegments.last} (${(oldSize / 1024).toStringAsFixed(1)} KB) ... ');

    try {
      // ffmpeg -y -i input.png -q:v 80 output.webp
      // -y 表示覆盖输出文件
      final result = await Process.run(
          'ffmpeg', ['-y', '-i', oldPath, '-q:v', '80', newPath]);

      if (result.exitCode != 0) {
        stdout
            .writeln('Failed to convert. ffmpeg exit code: ${result.exitCode}');
        stderr.writeln(result.stderr);
        continue;
      }

      final newFile = File(newPath);
      if (!newFile.existsSync()) {
        stdout.writeln('Failed. Output file not generated.');
        continue;
      }

      final newSize = newFile.lengthSync();
      totalNewSize += newSize;

      final savingPercent =
          ((oldSize - newSize) / oldSize * 100).toStringAsFixed(1);
      stdout.writeln(
          'Done. Saved to ${newFile.uri.pathSegments.last} (${(newSize / 1024).toStringAsFixed(1)} KB, -$savingPercent%)');

      // 删除原 PNG
      file.deleteSync();
    } catch (e) {
      stdout.writeln('Error: $e');
    }
  }

  final savingPercent =
      ((totalOldSize - totalNewSize) / totalOldSize * 100).toStringAsFixed(1);
  stdout.writeln('\nAll processed.');
  stdout.writeln(
      'Total PNG size: ${(totalOldSize / 1024 / 1024).toStringAsFixed(2)} MB');
  stdout.writeln(
      'Total WebP size: ${(totalNewSize / 1024 / 1024).toStringAsFixed(2)} MB');
  stdout.writeln('Overall space saved: -$savingPercent%');
}
