// scripts/download_emoticons.dart
// Run with: dart run scripts/download_emoticons.dart
//
// 从 S1-Next 仓库 assets 拉取六类麻将脸（精确 png/gif），写入
// assets/emoticons/{dir}/{code}.{ext} 与 manifest.json，随后应 git 提交入库。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// 与 lib/models/emoticon_catalog.dart 保持一致。
const packs = <({String dir, String prefix, int count})>[
  (dir: 'face2017', prefix: 'f', count: 275),
  (dir: 'carton2017', prefix: 'c', count: 430),
  (dir: 'animal2017', prefix: 'a', count: 30),
  (dir: 'device2017', prefix: 'd', count: 44),
  (dir: 'goose2017', prefix: 'g', count: 74),
  (dir: 'bundam2017', prefix: 'b', count: 37),
];

const s1NextAssetBase =
    'https://raw.githubusercontent.com/ykrank/S1-Next/master/'
    'app/src/main/assets/image/emoticon';

const cdnBase = 'https://static.stage1st.com/image/smiley';

const concurrency = 12;

Future<void> main() async {
  final root = Directory('assets/emoticons');
  if (!root.existsSync()) {
    root.createSync(recursive: true);
  }

  final client = http.Client();
  final manifest = <String, String>{};
  var ok = 0;
  var fail = 0;

  try {
    for (final pack in packs) {
      final packDir = Directory('${root.path}/${pack.dir}');
      if (!packDir.existsSync()) {
        packDir.createSync(recursive: true);
      }

      stdout.writeln('== ${pack.dir} (${pack.count}) ==');

      final codes = List<int>.generate(pack.count, (i) => i + 1);
      for (var i = 0; i < codes.length; i += concurrency) {
        final chunk = codes.skip(i).take(concurrency);
        await Future.wait(
          chunk.map((n) async {
            final code = n.toString().padLeft(3, '0');
            final dataCode = '${pack.prefix}:$code';
            final result = await _downloadOne(
              client,
              dir: pack.dir,
              code: code,
              outDir: packDir.path,
            );
            if (result == null) {
              stderr.writeln('FAIL $dataCode');
              fail++;
              return;
            }
            manifest[dataCode] = '${pack.dir}/$code.${result.ext}';
            ok++;
            if (ok % 50 == 0) {
              stdout.writeln('  saved $ok …');
            }
          }),
        );
      }
    }
  } finally {
    client.close();
  }

  final mapFile = File('${root.path}/manifest.json');
  final sorted = Map.fromEntries(
    manifest.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  await mapFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(sorted),
  );

  stdout.writeln('Done. ok=$ok fail=$fail manifest=${mapFile.path}');
  if (fail > 0) {
    exitCode = 1;
  }
}

class _Saved {
  const _Saved(this.ext);
  final String ext;
}

Future<_Saved?> _downloadOne(
  http.Client client, {
  required String dir,
  required String code,
  required String outDir,
}) async {
  for (final ext in ['png', 'gif']) {
    final candidates = [
      '$s1NextAssetBase/$dir/$code.$ext',
      '$cdnBase/$dir/$code.$ext',
    ];
    for (final url in candidates) {
      try {
        final res = await client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) continue;
        if (res.bodyBytes.isEmpty) continue;
        final file = File('$outDir/$code.$ext');
        await file.writeAsBytes(res.bodyBytes, flush: true);
        return _Saved(ext);
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
  }
  return null;
}
