/// 回复/编辑正文中的图片与附件 BBCode 解析辅助。
library;

import 'package:html/parser.dart' show parseFragment;

import 'post_image_urls.dart';

final _imgTagPattern = RegExp(
  r'\[img\](.*?)\[/img\]',
  caseSensitive: false,
  dotAll: true,
);

/// `[img]` / `[attachimg]` / `[attach]`（编辑页可能带回论坛原生附件码）。
final _mediaTagPattern = RegExp(
  r'\[img\](.*?)\[/img\]'
  r'|\[attachimg\](\d+)\[/attachimg\]'
  r'|\[attach\](\d+)\[/attach\]',
  caseSensitive: false,
  dotAll: true,
);

/// 从读帖/编辑页 HTML 提取 `aimg_{aid}` → 图片 URL。
///
/// 优先用外层 `<a href>` 原图（与 [PostImageUrls] 一致），否则用 `img src`。
Map<String, String> extractAttachImageUrls(String html) {
  if (html.trim().isEmpty) return const {};
  final map = <String, String>{};
  try {
    final fragment = parseFragment(html);
    final root = fragment;
    for (final img in root.querySelectorAll('img')) {
      final id = img.id.trim();
      if (!id.startsWith('aimg_')) continue;
      final aid = id.substring('aimg_'.length).trim();
      if (aid.isEmpty) continue;
      final src = img.attributes['src']?.trim() ?? '';
      String? href;
      var parent = img.parent;
      while (parent != null) {
        if (parent.localName == 'a') {
          href = parent.attributes['href']?.trim();
          break;
        }
        parent = parent.parent;
      }
      final resolved = PostImageUrls.resolve(src: src, linkHref: href);
      final url =
          resolved.fullUrl.isNotEmpty ? resolved.fullUrl : resolved.previewUrl;
      if (url.isNotEmpty) map[aid] = url;
    }
    for (final el in root.querySelectorAll('[aid]')) {
      final aid = el.attributes['aid']?.trim() ?? '';
      if (aid.isEmpty || map.containsKey(aid)) continue;
      final img = el.localName == 'img' ? el : el.querySelector('img');
      final src = img?.attributes['src']?.trim() ?? '';
      if (src.startsWith('http://') || src.startsWith('https://')) {
        map[aid] = src;
      }
    }
  } catch (_) {
    // HTML 异常时不影响编辑主流程。
  }
  return map;
}

final _attachimgTagPattern = RegExp(
  r'\[attachimg\](\d+)\[/attachimg\]',
  caseSensitive: false,
);

/// 预览用：把 `[attachimg]aid[/attachimg]` 换成已解析的 `[img]url[/img]`。
///
/// 提交仍应保留原始 `[attachimg]`，勿对写回正文使用本函数。
String rewriteAttachimgForPreview(
  String bbcode,
  Map<String, String> attachImageUrls,
) {
  if (bbcode.isEmpty || attachImageUrls.isEmpty) return bbcode;
  return bbcode.replaceAllMapped(_attachimgTagPattern, (match) {
    final aid = match.group(1) ?? '';
    final url = attachImageUrls[aid]?.trim() ?? '';
    if (url.isEmpty) return match.group(0)!;
    return '[img]$url[/img]';
  });
}

/// 预览正文里是否仍残留无法改写的 `[attachimg]`（缺 aid→URL）。
bool hasUnresolvedAttachimg(String bbcode) =>
    _attachimgTagPattern.hasMatch(bbcode);

/// Chip / 提示用：无预览地址时带上 aid，方便对照读帖。
String attachimgFallbackLabel(String aid, {required int index}) {
  final trimmed = aid.trim();
  if (trimmed.isEmpty) return '论坛图片 $index';
  return '论坛图片 · $trimmed';
}

/// 按出现顺序提取 URL（去重保序：首次出现为准）。
List<String> extractImgUrls(String text) {
  final seen = <String>{};
  final urls = <String>[];
  for (final match in _imgTagPattern.allMatches(text)) {
    final url = match.group(1)?.trim() ?? '';
    if (url.isEmpty || seen.contains(url)) continue;
    seen.add(url);
    urls.add(url);
  }
  return urls;
}

/// 一条可回写的媒体标记（外链表或论坛附件）。
class ComposeMediaTag {
  const ComposeMediaTag({
    required this.tag,
    required this.label,
    this.previewUrl,
  });

  /// 完整 BBCode，提交时原样写回。
  final String tag;

  /// Chip Tooltip / 无缩略图时的说明（文件名或「论坛图片 · aid」）。
  final String label;

  /// 可拉缩略图的地址：`[img]` 外链，或已解析的论坛 `[attachimg]`。
  final String? previewUrl;

  bool get isExternalImg => previewUrl != null && previewUrl!.isNotEmpty;

  bool get isAttachimg =>
      RegExp(r'^\[attachimg\]', caseSensitive: false).hasMatch(tag);

  bool get isForumAttach =>
      RegExp(r'^\[attach\]', caseSensitive: false).hasMatch(tag);
}

/// 正文与媒体标记拆分结果。
class ComposeMediaSplit {
  const ComposeMediaSplit({
    required this.body,
    required this.media,
    this.slots = const [],
  });

  /// 去掉媒体标签后的纯文本（空白已轻度收束）；编辑占位路径可含 `⟦图N⟧`。
  final String body;

  /// 按原文出现顺序的媒体标记。
  final List<ComposeMediaTag> media;

  /// 与 [media] 一一对应的稳定 slot；空列表表示按 1..n 赋值。
  final List<int> slots;

  List<int> get effectiveSlots {
    if (slots.length == media.length) return slots;
    return [for (var i = 0; i < media.length; i++) i + 1];
  }
}

/// 抽出 `[img]` / `[attachimg]` / `[attach]`，正文只留文字。
///
/// 编辑页用：输入框不堆长 URL；Chip 条管理图片；提交再 [appendComposeMedia]。
///
/// [attachImageUrls]：`aid → 图片 URL`，用于给论坛附件 Chip 填预览地址。
ComposeMediaSplit splitComposeMedia(
  String text, {
  Map<String, String> attachImageUrls = const {},
}) {
  final media = <ComposeMediaTag>[];
  var attachIndex = 0;
  for (final match in _mediaTagPattern.allMatches(text)) {
    final full = match.group(0) ?? '';
    if (full.isEmpty) continue;
    final imgUrl = match.group(1)?.trim();
    final attachImgId = match.group(2)?.trim();
    final attachId = match.group(3)?.trim();
    if (imgUrl != null && imgUrl.isNotEmpty) {
      media.add(
        ComposeMediaTag(
          tag: '[img]$imgUrl[/img]',
          label: filenameFromUrl(imgUrl),
          previewUrl: imgUrl,
        ),
      );
    } else if (attachImgId != null && attachImgId.isNotEmpty) {
      attachIndex += 1;
      final preview = attachImageUrls[attachImgId]?.trim();
      final hasPreview = preview != null && preview.isNotEmpty;
      media.add(
        ComposeMediaTag(
          tag: '[attachimg]$attachImgId[/attachimg]',
          label: hasPreview
              ? filenameFromUrl(preview)
              : attachimgFallbackLabel(attachImgId, index: attachIndex),
          previewUrl: hasPreview ? preview : null,
        ),
      );
    } else if (attachId != null && attachId.isNotEmpty) {
      attachIndex += 1;
      media.add(
        ComposeMediaTag(
          tag: '[attach]$attachId[/attach]',
          label: '论坛附件 · $attachId',
        ),
      );
    }
  }

  var body = text.replaceAll(_mediaTagPattern, '');
  body = body.replaceAll(RegExp(r'[^\S\n]{2,}'), ' ');
  body = body.replaceAll(RegExp(r' ?\n ?'), '\n');
  body = body.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return ComposeMediaSplit(
    body: body.trimRight(),
    media: media,
    slots: [for (var i = 0; i < media.length; i++) i + 1],
  );
}

/// 将媒体标记按序追加到正文末尾（中间空一行，若正文非空）。
String appendComposeMedia(String body, Iterable<String> tags) {
  final list = [for (final tag in tags) tag.trim()].where((t) => t.isNotEmpty);
  if (list.isEmpty) return body.trimRight();
  final joined = list.join('\n');
  final trimmed = body.trimRight();
  if (trimmed.isEmpty) return joined;
  return '$trimmed\n\n$joined';
}

/// 编辑页正文占位：`⟦图1⟧`（数字为稳定 slot，与 Chip 对应）。
final composeMediaPlaceholderPattern = RegExp(r'⟦图(\d+)⟧');

String composeMediaPlaceholder(int slot) => '⟦图$slot⟧';

int? parseComposeMediaPlaceholderSlot(String token) {
  final match = composeMediaPlaceholderPattern.firstMatch(token);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

/// 按出现顺序提取占位 slot（可重复；调用方决定是否去重）。
List<int> extractComposeMediaPlaceholderSlots(String text) {
  final slots = <int>[];
  for (final match in composeMediaPlaceholderPattern.allMatches(text)) {
    final slot = int.tryParse(match.group(1) ?? '');
    if (slot != null && slot > 0) slots.add(slot);
  }
  return slots;
}

String stripComposeMediaPlaceholders(String text) =>
    text.replaceAll(composeMediaPlaceholderPattern, '');

/// 抽出媒体标签，并在原位置留下 [composeMediaPlaceholder]。
///
/// 编辑页用：正文可挪动占位以改图文排版；提交再 [expandComposeMediaPlaceholders]。
ComposeMediaSplit splitComposeMediaWithPlaceholders(
  String text, {
  Map<String, String> attachImageUrls = const {},
}) {
  final media = <ComposeMediaTag>[];
  var attachIndex = 0;
  var slot = 0;
  final buffer = StringBuffer();
  var last = 0;
  for (final match in _mediaTagPattern.allMatches(text)) {
    buffer.write(text.substring(last, match.start));
    last = match.end;
    final full = match.group(0) ?? '';
    if (full.isEmpty) continue;
    final imgUrl = match.group(1)?.trim();
    final attachImgId = match.group(2)?.trim();
    final attachId = match.group(3)?.trim();
    ComposeMediaTag? item;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      item = ComposeMediaTag(
        tag: '[img]$imgUrl[/img]',
        label: filenameFromUrl(imgUrl),
        previewUrl: imgUrl,
      );
    } else if (attachImgId != null && attachImgId.isNotEmpty) {
      attachIndex += 1;
      final preview = attachImageUrls[attachImgId]?.trim();
      final hasPreview = preview != null && preview.isNotEmpty;
      item = ComposeMediaTag(
        tag: '[attachimg]$attachImgId[/attachimg]',
        label: hasPreview
            ? filenameFromUrl(preview)
            : attachimgFallbackLabel(attachImgId, index: attachIndex),
        previewUrl: hasPreview ? preview : null,
      );
    } else if (attachId != null && attachId.isNotEmpty) {
      attachIndex += 1;
      item = ComposeMediaTag(
        tag: '[attach]$attachId[/attach]',
        label: '论坛附件 · $attachId',
      );
    }
    if (item == null) continue;
    slot += 1;
    media.add(item);
    buffer.write(composeMediaPlaceholder(slot));
  }
  buffer.write(text.substring(last));

  var body = buffer.toString();
  body = body.replaceAll(RegExp(r'[^\S\n]{2,}'), ' ');
  body = body.replaceAll(RegExp(r' ?\n ?'), '\n');
  body = body.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return ComposeMediaSplit(
    body: body.trimRight(),
    media: media,
    slots: [for (var i = 0; i < media.length; i++) i + 1],
  );
}

/// 把正文里的 `⟦图N⟧` 还原为 [tagsBySlot] 中对应 slot 的 BBCode。
///
/// 无效占位删除；未被引用的 tag 按 slot 升序追加到文末（防丢图）。
///
/// 必须用 slot→tag 映射，不能用 Chip 列表下标：用户挪动占位后 Chip 顺序会变，
/// 但 `⟦图N⟧` 的 N 仍对应稳定 slot。
String expandComposeMediaPlaceholders(
  String body,
  Map<int, String> tagsBySlot,
) {
  final used = <int>{};
  final expanded = body.replaceAllMapped(composeMediaPlaceholderPattern, (m) {
    final slot = int.tryParse(m.group(1) ?? '') ?? 0;
    final tag = tagsBySlot[slot]?.trim() ?? '';
    if (slot < 1 || tag.isEmpty) return '';
    used.add(slot);
    return tag;
  });
  final unusedSlots = tagsBySlot.keys.where((s) => !used.contains(s)).toList()
    ..sort();
  final unused = [
    for (final slot in unusedSlots)
      if ((tagsBySlot[slot] ?? '').trim().isNotEmpty) tagsBySlot[slot]!.trim(),
  ];
  if (unused.isEmpty) return expanded.trimRight();
  return appendComposeMedia(expanded, unused);
}

/// 从正文移除指定 slot 的占位。
String removeComposeMediaPlaceholder(String text, int slot) {
  return text.replaceAll(composeMediaPlaceholder(slot), '');
}

/// 在光标处插入媒体占位。
({String text, int cursor}) insertComposeMediaPlaceholderAt({
  required String text,
  required int start,
  required int end,
  required int slot,
}) {
  return insertSnippetPadded(
    text: text,
    start: start,
    end: end,
    snippet: composeMediaPlaceholder(slot),
  );
}

/// 移除正文中所有指向 [url] 的 `[img]…[/img]`。
String removeImgTag(String text, String url) {
  final tag = '[img]$url[/img]';
  return text.replaceAll(tag, '');
}

/// Chip 可见短标签。
String displayLabelForIndex(int index) => '图片 ${index + 1}';

/// 从 URL path 取文件名，供 Tooltip。
String filenameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final seg = uri?.pathSegments;
  if (seg != null && seg.isNotEmpty) {
    final name = seg.last.trim();
    if (name.isNotEmpty) {
      try {
        return Uri.decodeComponent(name);
      } on ArgumentError {
        return name;
      }
    }
  }
  return url;
}

/// 在光标处插入 `[img]url[/img]`，必要时前后补空格避免与文字粘连。
({String text, int cursor}) insertImgTagAt({
  required String text,
  required int start,
  required int end,
  required String url,
}) {
  final tag = '[img]$url[/img]';
  return insertSnippetPadded(
    text: text,
    start: start,
    end: end,
    snippet: tag,
  );
}

/// 在光标处插入片段；若与邻接非空白字符相贴则补空格。
({String text, int cursor}) insertSnippetPadded({
  required String text,
  required int start,
  required int end,
  required String snippet,
}) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  var piece = snippet;
  var cursorOffset = snippet.length;

  if (safeStart > 0) {
    final prev = text[safeStart - 1];
    if (!_isWhitespace(prev) && !_isWhitespace(snippet[0])) {
      piece = ' $piece';
      cursorOffset += 1;
    }
  }
  if (safeEnd < text.length) {
    final next = text[safeEnd];
    if (!_isWhitespace(next) && !_isWhitespace(piece[piece.length - 1])) {
      piece = '$piece ';
    }
  }

  final nextText = text.replaceRange(safeStart, safeEnd, piece);
  return (text: nextText, cursor: safeStart + cursorOffset);
}

/// 表情实体插入：后接中文/字母数字时补尾随空格。
({String text, int cursor}) insertEmoticonEntity({
  required String text,
  required int start,
  required int end,
  required String entity,
}) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  var piece = entity;
  var cursorOffset = entity.length;

  if (safeEnd < text.length && _needsTrailingSpace(text[safeEnd])) {
    piece = '$piece ';
  }

  final nextText = text.replaceRange(safeStart, safeEnd, piece);
  return (text: nextText, cursor: safeStart + cursorOffset);
}

bool _isWhitespace(String ch) =>
    ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';

bool _needsTrailingSpace(String next) {
  if (_isWhitespace(next)) return false;
  if (RegExp(r'[A-Za-z0-9]').hasMatch(next)) return true;
  final code = next.runes.first;
  // CJK Unified Ideographs + common CJK punctuation-adjacent letters
  return code >= 0x4E00 && code <= 0x9FFF;
}

/// 最近表情：去重顶置，最多 [max]。
List<String> pushRecentEmoticon(
  List<String> current,
  String entity, {
  int max = 24,
}) {
  final next = <String>[entity, ...current.where((e) => e != entity)];
  if (next.length > max) {
    return next.sublist(0, max);
  }
  return next;
}
