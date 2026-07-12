/// S1 论坛评分表单选项（从 Discuz rate 弹窗 HTML 解析）。
class RateFormOptions {
  const RateFormOptions({
    required this.scoreOptions,
    required this.reasonPresets,
    this.error,
  });

  factory RateFormOptions.withDefaults({String? error}) {
    return RateFormOptions(
      scoreOptions: defaultScoreOptions,
      reasonPresets: defaultReasonPresets,
      error: error,
    );
  }

  /// 战斗力预设分值（如 `0`, `+2`, `+1`, `-1`, `-2`）。
  final List<String> scoreOptions;

  /// 理由预设（首项可为空字符串表示无预设）。
  final List<String> reasonPresets;

  /// 预取阶段的服务端错误（如自评、无权限）。
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  /// S1 常见默认预设（解析失败时回退）。
  static const List<String> defaultScoreOptions = [
    '0',
    '+2',
    '+1',
    '-1',
    '-2',
  ];

  static const List<String> defaultReasonPresets = [
    '',
    '好评加鹅',
    '欢乐多',
    '思路广',
  ];
}
