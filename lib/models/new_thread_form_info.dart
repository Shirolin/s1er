/// 新主题预检结果。
class NewThreadFormInfo {
  const NewThreadFormInfo({
    this.threadTypes = const {},
    this.typeRequired = false,
    this.formhash,
    this.error,
  });

  final Map<String, String> threadTypes;
  final bool typeRequired;
  final String? formhash;
  final String? error;

  bool get canSubmit =>
      error == null &&
      formhash != null &&
      formhash!.isNotEmpty &&
      (!typeRequired || threadTypes.isNotEmpty);
}
