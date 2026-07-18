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
