/// compose 插图上传结果（论坛附件或外链）。
class ComposeImageUploadResult {
  const ComposeImageUploadResult({
    required this.insertTag,
    required this.label,
    this.previewUrl,
    this.aid,
  });

  /// 写入正文的 BBCode：`[attachimg]aid[/attachimg]` 或 `[img]url[/img]`。
  final String insertTag;

  /// Chip / 提示用文件名。
  final String label;

  /// 预览缩略图 URL（论坛经 imagelist；外链即公网地址）。
  final String? previewUrl;

  /// 论坛附件 aid；外链为 null。
  final String? aid;

  bool get isForumAttachment => aid != null && aid!.isNotEmpty;
}
