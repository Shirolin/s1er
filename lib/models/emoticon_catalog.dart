/// S1 麻将脸目录（对齐 S1-Next [EmoticonFactory]）。
///
/// 资源路径：`assets/emoticons/{dir}/{code}.{png|gif}`（入库打包）。
/// 后缀以 [applyManifest] 为准；无清单时默认 `png`（运行时 asset 失败再走 CDN）。
library;

class EmoticonPack {
  const EmoticonPack({
    required this.title,
    required this.dir,
    required this.entityPrefix,
    required this.count,
  });

  final String title;
  final String dir;
  final String entityPrefix;
  final int count;
}

class EmoticonItem {
  const EmoticonItem({
    required this.pack,
    required this.index,
    this.ext,
  });

  final EmoticonPack pack;
  final int index;

  /// 确切后缀（`png` / `gif`）；null 表示清单未提供。
  final String? ext;

  String get code => index.toString().padLeft(3, '0');

  /// 写入回复正文的 BBCode 实体。
  String get entity => '[${pack.entityPrefix}:$code]';

  /// `data-code` 属性用（无方括号）。
  String get dataCode => '${pack.entityPrefix}:$code';

  String get resolvedExt {
    final fromField = ext?.toLowerCase();
    if (fromField == 'png' || fromField == 'gif') return fromField!;
    final fromManifest = EmoticonCatalog.extForDataCode(dataCode);
    if (fromManifest != null) return fromManifest;
    return 'png';
  }

  /// 相对目录文件，如 `face2017/001.gif`。
  String get relativePath => '${pack.dir}/$code.$resolvedExt';

  String get assetPath => 'assets/emoticons/$relativePath';

  String get networkUrl =>
      '${EmoticonCatalog.staticSmileyBase}$relativePath';
}

abstract final class EmoticonCatalog {
  static const staticSmileyBase =
      'https://static.stage1st.com/image/smiley/';

  static const assetRoot = 'assets/emoticons';

  /// dataCode (`f:001`) → 相对路径 (`face2017/001.gif`)
  static final Map<String, String> _manifest = {};

  /// Tab 顺序与 S1-Next `emoticon_type` / `getEmoticonsByIndex` 一致。
  static const packs = <EmoticonPack>[
    EmoticonPack(
      title: '麻将脸',
      dir: 'face2017',
      entityPrefix: 'f',
      count: 275,
    ),
    EmoticonPack(
      title: '动漫',
      dir: 'carton2017',
      entityPrefix: 'c',
      count: 430,
    ),
    EmoticonPack(
      title: '动物',
      dir: 'animal2017',
      entityPrefix: 'a',
      count: 30,
    ),
    EmoticonPack(
      title: '硬件',
      dir: 'device2017',
      entityPrefix: 'd',
      count: 44,
    ),
    EmoticonPack(
      title: '鹅',
      dir: 'goose2017',
      entityPrefix: 'g',
      count: 74,
    ),
    EmoticonPack(
      title: '高达',
      dir: 'bundam2017',
      entityPrefix: 'b',
      count: 37,
    ),
  ];

  static Map<String, String> get manifest => Map.unmodifiable(_manifest);

  /// 应用 `manifest.json`：值为 `face2017/001.gif` 或完整 asset 相对段。
  static void applyManifest(Map<String, dynamic> raw) {
    _manifest.clear();
    raw.forEach((key, value) {
      if (value is! String || value.isEmpty) return;
      final dataCode = key.startsWith('[') && key.endsWith(']')
          ? key.substring(1, key.length - 1)
          : key;
      var rel = value;
      if (rel.startsWith('assets/emoticons/')) {
        rel = rel.substring('assets/emoticons/'.length);
      }
      _manifest[dataCode.toLowerCase()] = rel;
    });
  }

  static void clearManifest() => _manifest.clear();

  static String? extForDataCode(String dataCode) {
    final rel = _manifest[dataCode.toLowerCase()];
    if (rel == null) return null;
    final dot = rel.lastIndexOf('.');
    if (dot < 0 || dot == rel.length - 1) return null;
    final e = rel.substring(dot + 1).toLowerCase();
    if (e == 'png' || e == 'gif') return e;
    return null;
  }

  static List<EmoticonItem> itemsFor(EmoticonPack pack) {
    return List<EmoticonItem>.generate(
      pack.count,
      (i) {
        final index = i + 1;
        final code = index.toString().padLeft(3, '0');
        final dataCode = '${pack.entityPrefix}:$code';
        return EmoticonItem(
          pack: pack,
          index: index,
          ext: extForDataCode(dataCode),
        );
      },
      growable: false,
    );
  }

  /// 解析 `[f:001]` / `f:001` → 目录项；未知返回 null。
  static EmoticonItem? findByCode(String raw) {
    final match = RegExp(r'^\[?([facdgb]):(\d+)\]?$', caseSensitive: false)
        .firstMatch(raw.trim());
    if (match == null) return null;
    final prefix = match.group(1)!.toLowerCase();
    final index = int.tryParse(match.group(2)!);
    if (index == null || index < 1) return null;

    for (final pack in packs) {
      if (pack.entityPrefix != prefix) continue;
      if (index > pack.count) return null;
      final code = index.toString().padLeft(3, '0');
      final dataCode = '${pack.entityPrefix}:$code';
      return EmoticonItem(
        pack: pack,
        index: index,
        ext: extForDataCode(dataCode),
      );
    }
    return null;
  }

  /// 从论坛 / CDN URL 反解，如 `…/image/smiley/face2017/004.gif`。
  static EmoticonItem? fromSmileyUrl(String src) {
    final uri = Uri.tryParse(src.trim());
    final path = uri?.path ?? src;
    final match = RegExp(
      r'(?:/|^)image/smiley/([a-zA-Z0-9_]+)/(\d+)\.(png|gif|jpe?g|webp)',
      caseSensitive: false,
    ).firstMatch(path);
    if (match == null) return null;

    final dir = match.group(1)!;
    final index = int.tryParse(match.group(2)!);
    final fileExt = match.group(3)!.toLowerCase();
    if (index == null || index < 1) return null;

    for (final pack in packs) {
      if (pack.dir != dir) continue;
      if (index > pack.count) return null;
      final ext = (fileExt == 'jpg' || fileExt == 'jpeg' || fileExt == 'webp')
          ? null
          : fileExt;
      return EmoticonItem(pack: pack, index: index, ext: ext);
    }
    return null;
  }
}
