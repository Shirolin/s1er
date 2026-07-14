/// S1 麻将脸目录（对齐 S1-Next [EmoticonFactory]）。
///
/// 插入正文的实体码形如 `[f:001]`；面板预览默认走
/// `https://static.stage1st.com/image/smiley/{dir}/{code}.png`，失败回退 `.gif`。
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
  });

  final EmoticonPack pack;
  final int index;

  String get code => index.toString().padLeft(3, '0');

  /// 写入回复正文的 BBCode 实体。
  String get entity => '[${pack.entityPrefix}:$code]';

  /// `data-code` 属性用（无方括号）。
  String get dataCode => '${pack.entityPrefix}:$code';

  String get pngUrl =>
      '${EmoticonCatalog.staticSmileyBase}${pack.dir}/$code.png';

  String get gifUrl =>
      '${EmoticonCatalog.staticSmileyBase}${pack.dir}/$code.gif';
}

abstract final class EmoticonCatalog {
  static const staticSmileyBase =
      'https://static.stage1st.com/image/smiley/';

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

  static List<EmoticonItem> itemsFor(EmoticonPack pack) {
    return List<EmoticonItem>.generate(
      pack.count,
      (i) => EmoticonItem(pack: pack, index: i + 1),
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
      return EmoticonItem(pack: pack, index: index);
    }
    return null;
  }

  /// 用于面板 / EmoticonWidget 的首选网络地址（png）。
  static String? primaryNetworkUrl(String rawCode) {
    return findByCode(rawCode)?.pngUrl;
  }

  static String? fallbackNetworkUrl(String rawCode) {
    return findByCode(rawCode)?.gifUrl;
  }
}
