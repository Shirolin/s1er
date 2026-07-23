import '../models/forum_attachment_upload_info.dart';

class EditPostFormInfo {
  const EditPostFormInfo({
    this.subject = '',
    this.message = '',
    this.threadTypes = const {},
    this.selectedTypeId,
    this.readPermissions = const [],
    this.selectedReadPermission,
    this.formhash,
    this.isFirst = false,
    this.special = 0,
    this.attachImageUrls = const {},
    this.attachmentUploadInfo,
    this.error,
  });

  final String subject;
  final String message;
  final Map<String, String> threadTypes;
  final String? selectedTypeId;
  final List<String> readPermissions;
  final String? selectedReadPermission;
  final String? formhash;
  final bool isFirst;
  final int special;

  /// 编辑页 / 读帖 HTML 解析出的 `aid → 图片 URL`（预览 `[attachimg]` 用）。
  final Map<String, String> attachImageUrls;

  /// 编辑页刮取的论坛附件上传凭据（可缺）。
  final ForumAttachmentUploadInfo? attachmentUploadInfo;

  final String? error;

  bool get canEdit =>
      error == null &&
      message.trim().isNotEmpty &&
      formhash != null &&
      formhash!.isNotEmpty &&
      (isFirst ? special == 0 : true);

  bool get hasTypeSelector => threadTypes.isNotEmpty;
  bool get hasReadPermissionSelector => readPermissions.isNotEmpty;
}
