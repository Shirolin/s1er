// scripts/download_emoticons.dart
//
// 维护工具：从 kawaiidora/s1emoticon 的 GitHub Release 按清单补齐本地表情。
// 日常开发 / CI / 提交都不要跑。表情默认已入库。
//
// 清单：
//   assets/emoticons/packs.json         — 包定义（App Tab / count）
//   assets/emoticons/download_list.txt  — 要入库的 dataCode（f:001 …）
//   assets/emoticons/ATTRIBUTION.md     — 来源与无许可证声明（必读）
//
// 用法：
//   dart run scripts/download_emoticons.dart
//   dart run scripts/download_emoticons.dart --dry-run
//   dart run scripts/download_emoticons.dart --write-list
//   dart run scripts/download_emoticons.dart --force
//   dart run scripts/download_emoticons.dart --tag=r5.13
//
// 来源：https://github.com/kawaiidora/s1emoticon/releases （一次拉 zip，不扫论坛 CDN）

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

const packsPath = 'assets/emoticons/packs.json';
const listPath = 'assets/emoticons/download_list.txt';
const attributionPath = 'assets/emoticons/ATTRIBUTION.md';
const assetRoot = 'assets/emoticons';

/// 与 ATTRIBUTION.md 一致；升级表情包时改此标签并更新声明。
const defaultReleaseTag = 'r5.13';

const releaseApi =
    'https://api.github.com/repos/kawaiidora/s1emoticon/releases/tags';
const releaseLatestApi =
    'https://api.github.com/repos/kawaiidora/s1emoticon/releases/latest';

typedef Pack = ({String title, String dir, String prefix, int count});

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final force = args.contains('--force');
  final writeList = args.contains('--write-list');
  final tag = _argValue(args, '--tag') ?? defaultReleaseTag;

  final packs = await _loadPacks();
  if (packs.isEmpty) {
    stderr.writeln('ERROR: no packs in $packsPath');
    exitCode = 1;
    return;
  }

  if (writeList) {
    await _writeListFromPacks(packs);
    stdout.writeln('Wrote $listPath from $packsPath');
    return;
  }

  final wanted = await _loadDownloadList(packs);
  if (wanted.isEmpty) {
    stderr.writeln('ERROR: empty download list ($listPath)');
    exitCode = 1;
    return;
  }

  stdout.writeln('''
════════════════════════════════════════
  download_emoticons
  来源: kawaiidora/s1emoticon @ $tag (GitHub Release zip)
  声明: $attributionPath （该仓当前无 LICENSE）
  清单: $listPath (${wanted.length} 项)
  模式: ${dryRun ? 'dry-run' : force ? 'FORCE' : '只补本地缺失'}
  请勿在 CI / 循环中运行；勿对论坛 CDN 全量扫描。
════════════════════════════════════════
''');

  if (force && !dryRun) {
    stderr.write('输入 yes 继续覆盖本地已有文件: ');
    if (stdin.readLineSync()?.trim() != 'yes') {
      stderr.writeln('已取消。');
      exitCode = 1;
      return;
    }
  }

  if (dryRun) {
    final byPrefix = {for (final p in packs) p.prefix: p};
    var missing = 0;
    for (final dataCode in wanted) {
      final parsed = _parseDataCode(dataCode);
      if (parsed == null) continue;
      final pack = byPrefix[parsed.prefix];
      if (pack == null) continue;
      final code = parsed.index.toString().padLeft(3, '0');
      if (_existingFile('$assetRoot/${pack.dir}', code) == null) {
        stdout.writeln('  would import $dataCode');
        missing++;
      }
    }
    stdout.writeln('Dry-run: $missing missing of ${wanted.length}');
    return;
  }

  final zipBytes = await _downloadReleaseZip(tag);
  final imported = await _importFromZip(
    zipBytes,
    packs: packs,
    wanted: wanted.toSet(),
    force: force,
  );

  await _rewriteManifest(packs);
  stdout.writeln(
    'Done. imported=${imported.imported} skipped=${imported.skipped} '
    'missingInZip=${imported.missingInZip}',
  );
  if (imported.missingInZip > 0) exitCode = 1;
}

String? _argValue(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}

Future<List<Pack>> _loadPacks() async {
  final file = File(packsPath);
  if (!file.existsSync()) return const [];
  final decoded = jsonDecode(await file.readAsString());
  final list = switch (decoded) {
    final Map<String, dynamic> m => m['packs'],
    final List<dynamic> l => l,
    _ => null,
  };
  if (list is! List) return const [];
  final out = <Pack>[];
  for (final e in list) {
    if (e is! Map) continue;
    final map = Map<String, dynamic>.from(e);
    final dir = map['dir'] as String?;
    final prefix = map['prefix'] as String?;
    final count = (map['count'] as num?)?.toInt();
    final title = map['title'] as String? ?? dir ?? '';
    if (dir == null || prefix == null || count == null || count < 1) continue;
    out.add((title: title, dir: dir, prefix: prefix, count: count));
  }
  return out;
}

Future<void> _writeListFromPacks(List<Pack> packs) async {
  final buf = StringBuffer()
    ..writeln(
        '# S1er emoticon download list — one dataCode per line (e.g. f:001).')
    ..writeln(
        '# 来源仓库: https://github.com/kawaiidora/s1emoticon （见 ATTRIBUTION.md）')
    ..writeln('# 1) 对照论坛 / s1emoticon 更新 packs.json')
    ..writeln('# 2) dart run scripts/download_emoticons.dart --write-list')
    ..writeln('# 3) 可再手工增删本文件，然后:')
    ..writeln('#      dart run scripts/download_emoticons.dart')
    ..writeln('# 从 GitHub Release zip 导入；勿进 CI。')
    ..writeln('');

  for (final pack in packs) {
    buf.writeln(
        '# ${pack.dir} ${pack.title} (${pack.prefix}:1..${pack.count})');
    for (var n = 1; n <= pack.count; n++) {
      buf.writeln('${pack.prefix}:${n.toString().padLeft(3, '0')}');
    }
    buf.writeln('');
  }
  await File(listPath).writeAsString(buf.toString());
}

Future<List<String>> _loadDownloadList(List<Pack> packs) async {
  final file = File(listPath);
  if (!file.existsSync()) {
    stderr.writeln('WARN: $listPath missing — generating from packs.json');
    await _writeListFromPacks(packs);
  }
  final out = <String>[];
  final seen = <String>{};
  for (final line in await file.readAsLines()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final code = trimmed.toLowerCase();
    if (seen.add(code)) out.add(code);
  }
  return out;
}

({String prefix, int index})? _parseDataCode(String raw) {
  final m = RegExp(r'^([a-z]):(\d+)$', caseSensitive: false).firstMatch(raw);
  if (m == null) return null;
  final index = int.tryParse(m.group(2)!);
  if (index == null || index < 1) return null;
  return (prefix: m.group(1)!.toLowerCase(), index: index);
}

Future<List<int>> _downloadReleaseZip(String tag) async {
  final apiUrl = tag == 'latest' ? releaseLatestApi : '$releaseApi/$tag';
  stdout.writeln('Fetching release metadata: $apiUrl');
  final metaRes = await http.get(
    Uri.parse(apiUrl),
    headers: const {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 's1er-emoticon-maintainer',
    },
  ).timeout(const Duration(seconds: 60));
  if (metaRes.statusCode != 200) {
    throw StateError(
      'GitHub release API ${metaRes.statusCode}: ${metaRes.body}',
    );
  }
  final meta = jsonDecode(metaRes.body) as Map<String, dynamic>;
  final assets = meta['assets'] as List<dynamic>? ?? const [];
  Map<String, dynamic>? zipAsset;
  for (final a in assets) {
    if (a is! Map) continue;
    final name = (a['name'] as String?)?.toLowerCase() ?? '';
    if (name.endsWith('.zip')) {
      zipAsset = Map<String, dynamic>.from(a);
      break;
    }
  }
  if (zipAsset == null) {
    throw StateError('No .zip asset on release $tag');
  }
  final url = zipAsset['browser_download_url'] as String;
  stdout.writeln('Downloading ${zipAsset['name']} …');
  final zipRes = await http.get(Uri.parse(url), headers: const {
    'User-Agent': 's1er-emoticon-maintainer'
  }).timeout(const Duration(minutes: 5));
  if (zipRes.statusCode != 200) {
    throw StateError('Zip download ${zipRes.statusCode}');
  }
  stdout.writeln('Downloaded ${(zipRes.bodyBytes.length / 1024).round()} KiB');
  return zipRes.bodyBytes;
}

class _ImportStats {
  int imported = 0;
  int skipped = 0;
  int missingInZip = 0;
}

Future<_ImportStats> _importFromZip(
  List<int> zipBytes, {
  required List<Pack> packs,
  required Set<String> wanted,
  required bool force,
}) async {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final byPrefix = {for (final p in packs) p.prefix: p};

  // path key "face2017/001" → bytes + ext；prefer "without prefixs" trees
  final candidates = <String, ({List<int> bytes, String ext})>{};
  for (final file in archive) {
    if (!file.isFile) continue;
    final name = file.name.replaceAll('\\', '/');
    final lower = name.toLowerCase();
    if (!lower.contains('without prefix')) continue;
    final match = RegExp(
      r'(face2017|carton2017|animal2017|device2017|goose2017|bundam2017)/(\d{3})\.(png|gif)$',
      caseSensitive: false,
    ).firstMatch(name);
    if (match == null) continue;
    final dir = match.group(1)!.toLowerCase();
    final code = match.group(2)!;
    final ext = match.group(3)!.toLowerCase();
    final key = '$dir/$code';
    // Later entries (e.g. 增补包) overwrite earlier ones.
    candidates[key] = (bytes: List<int>.from(file.content), ext: ext);
  }

  if (candidates.isEmpty) {
    throw StateError(
      'Zip has no without-prefix face2017/… files; check s1emoticon release layout',
    );
  }

  final stats = _ImportStats();
  final root = Directory(assetRoot)..createSync(recursive: true);

  for (final dataCode in wanted) {
    final parsed = _parseDataCode(dataCode);
    if (parsed == null) {
      stderr.writeln('SKIP bad code: $dataCode');
      continue;
    }
    final pack = byPrefix[parsed.prefix];
    if (pack == null) {
      stderr.writeln('SKIP unknown prefix: $dataCode');
      continue;
    }
    if (parsed.index > pack.count) {
      stderr.writeln('SKIP $dataCode > packs.json count=${pack.count}');
      continue;
    }
    final code = parsed.index.toString().padLeft(3, '0');
    final packDir = Directory('${root.path}/${pack.dir}')
      ..createSync(recursive: true);
    final existing = _existingFile(packDir.path, code);
    if (!force && existing != null) {
      stats.skipped++;
      continue;
    }

    final key = '${pack.dir.toLowerCase()}/$code';
    final src = candidates[key];
    if (src == null) {
      stderr.writeln('MISSING in zip: $dataCode ($key)');
      stats.missingInZip++;
      continue;
    }

    for (final other in ['png', 'gif']) {
      if (other == src.ext) continue;
      final rival = File('${packDir.path}/$code.$other');
      if (rival.existsSync()) rival.deleteSync();
    }
    await File('${packDir.path}/$code.${src.ext}')
        .writeAsBytes(src.bytes, flush: true);
    stats.imported++;
  }

  return stats;
}

Future<void> _rewriteManifest(List<Pack> packs) async {
  final merged = <String, String>{};
  for (final pack in packs) {
    final packDir = Directory('$assetRoot/${pack.dir}');
    for (var n = 1; n <= pack.count; n++) {
      final code = n.toString().padLeft(3, '0');
      final existing = _existingFile(packDir.path, code);
      if (existing != null) {
        merged['${pack.prefix}:$code'] = '${pack.dir}/$code.${existing.ext}';
      }
    }
  }
  final sorted = Map.fromEntries(
    merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  await File('$assetRoot/manifest.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(sorted),
  );
}

class _Saved {
  const _Saved(this.ext);
  final String ext;
}

_Saved? _existingFile(String outDir, String code) {
  for (final ext in ['png', 'gif']) {
    final file = File('$outDir/$code.$ext');
    if (file.existsSync() && file.lengthSync() > 0) return _Saved(ext);
  }
  return null;
}
