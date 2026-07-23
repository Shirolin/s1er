/// Discuz 论坛附件上传凭据（从发帖/回复/编辑页 HTML 解析）。
class ForumAttachmentUploadInfo {
  const ForumAttachmentUploadInfo({
    required this.hash,
    required this.fid,
    this.uid,
    this.uploadUrl,
    this.formhash,
  });

  /// swfupload multipart 的 `hash`。
  final String hash;

  /// 版块 id（上传 URL / imagelist 需要）。
  final String fid;

  /// 上传者 uid；缺省时由登录态补齐。
  final String? uid;

  /// 完整或相对上传 URL；空则用默认 `misc.php?mod=swfupload…`。
  final String? uploadUrl;

  /// 编辑/发帖页里的 formhash（网页提交可用）。
  final String? formhash;

  bool get isValid => hash.trim().isNotEmpty && fid.trim().isNotEmpty;
}
