/// 打开编辑页时携带的附加数据（避免把长 URL 塞进 query）。
class EditPostRouteExtra {
  const EditPostRouteExtra({
    this.attachImageUrls = const {},
  });

  /// 从读帖 HTML 解析的 `aid → 图片 URL`。
  final Map<String, String> attachImageUrls;
}
