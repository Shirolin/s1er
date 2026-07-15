/// S1 论坛楼层举报表单。
class ReportFormOptions {
  const ReportFormOptions({
    required this.reasons,
    required this.fields,
    this.error,
    this.retryable = false,
  });

  factory ReportFormOptions.withDefaults({
    String? error,
    bool retryable = false,
    Map<String, String> fields = const <String, String>{},
  }) {
    return ReportFormOptions(
      reasons: defaultReasons,
      fields: fields,
      error: error,
      retryable: retryable,
    );
  }

  static const List<String> defaultReasons = <String>[
    '广告垃圾',
    '违规内容',
    '恶意灌水',
    '重复发帖',
    '其他',
  ];

  final List<String> reasons;
  final Map<String, String> fields;
  final String? error;
  final bool retryable;

  bool get hasError => error != null && error!.isNotEmpty;
}
