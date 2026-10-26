/// 论坛帖子的附件元数据（Mobile API `postlist[].attachments`，key 为 aid）。
///
/// 正文里只给 `[attach]aid[/attach]` / `[attachimg]aid[/attachimg]`，
/// 真实文件地址需要拼 [url] + [attachment]。
class PostAttachment {
  const PostAttachment({
    required this.aid,
    this.filename = '',
    this.path = '',
    this.baseUrl = '',
    this.isImage = false,
    this.attachImg = false,
    this.sizeLabel = '',
    this.width = 0,
    this.height = 0,
  });

  /// 附件 id（正文 `[attach]` 里的数字）。
  final String aid;

  /// 原始文件名，如 `QQ截图20261013154029.png`。
  final String filename;

  /// 相对路径，如 `202610/13/154803pzzyvpddgdljlzjh.png`。
  final String path;

  /// 图片域名前缀，如 `https://img.stage1st.com/forum/`。
  final String baseUrl;

  /// `isimage == "1"`：按图片渲染。
  final bool isImage;

  /// `attachimg == "1"`：帖子内按图片展示（非附件链接）。
  final bool attachImg;

  /// 人类可读大小，如 `99.34 KB`。
  final String sizeLabel;

  final int width;
  final int height;

  bool get isRenderable => isImage || attachImg;

  /// 可直接放进 `[img]` / `src` 的绝对地址；无法拼出时返回空串。
  String get imageUrl {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (baseUrl.isEmpty) return '';
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$base$path';
  }

  /// 非图片附件（或地址拼不出）时的展示文案。
  String get label {
    final name = filename.isNotEmpty ? filename : '附件 $aid';
    return sizeLabel.isEmpty ? name : '$name（$sizeLabel）';
  }

  /// 解析单条附件对象；缺少 aid 时返回 `null`。
  static PostAttachment? fromJson(Map<String, dynamic> json, {String? aidKey}) {
    final aid = (json['aid']?.toString().trim().isNotEmpty ?? false)
        ? json['aid']!.toString().trim()
        : (aidKey?.trim() ?? '');
    if (aid.isEmpty) return null;
    return PostAttachment(
      aid: aid,
      filename: json['filename']?.toString() ?? '',
      path: json['attachment']?.toString() ?? '',
      baseUrl: json['url']?.toString() ?? '',
      isImage: json['isimage']?.toString() == '1',
      attachImg: json['attachimg']?.toString() == '1',
      sizeLabel: json['attachsize']?.toString() ?? '',
      width: int.tryParse(json['width']?.toString() ?? '') ?? 0,
      height: int.tryParse(json['height']?.toString() ?? '') ?? 0,
    );
  }

  /// 解析 `postlist[].attachments`。
  ///
  /// Discuz 在无附件时给空数组、有附件时给以 aid 为 key 的对象，两种都要容忍。
  static Map<String, PostAttachment> parseMap(dynamic raw) {
    final result = <String, PostAttachment>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final parsed = PostAttachment.fromJson(
          Map<String, dynamic>.from(value),
          aidKey: entry.key.toString(),
        );
        if (parsed != null) result[parsed.aid] = parsed;
      }
    } else if (raw is List) {
      for (final value in raw) {
        if (value is! Map) continue;
        final parsed = PostAttachment.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (parsed != null) result[parsed.aid] = parsed;
      }
    }
    return result;
  }
}
