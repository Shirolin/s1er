/// S1 论坛评分表单选项（从 Discuz rate 弹窗 HTML 解析）。
class RateFormOptions {
  const RateFormOptions({
    required this.scoreOptions,
    required this.reasonPresets,
    this.formHash,
    this.tid,
    this.pid,
    this.referer,
    this.handleKey,
    this.minScore,
    this.maxScore,
    this.totalScore,
    this.notifyAuthorDefault = false,
    this.notifyAuthorDisabled = false,
    this.retryable = false,
    this.error,
  });

  factory RateFormOptions.withDefaults({
    String? error,
    bool retryable = false,
  }) {
    return RateFormOptions(
      scoreOptions: defaultScoreOptions,
      reasonPresets: defaultReasonPresets,
      error: error,
      retryable: retryable,
    );
  }

  /// 战斗力预设分值（如 `0`, `+2`, `+1`, `-1`, `-2`）。
  final List<String> scoreOptions;

  /// 理由预设（首项可为空字符串表示无预设）。
  final List<String> reasonPresets;

  /// 服务端评分表单中的隐藏字段。
  final String? formHash;
  final String? tid;
  final String? pid;
  final String? referer;
  final String? handleKey;

  /// 当前用户组允许的评分范围。
  final int? minScore;
  final int? maxScore;

  /// 当前楼层已有总战斗力。
  final int? totalScore;

  /// 是否默认通知作者，以及服务端是否禁用该选项。
  final bool notifyAuthorDefault;
  final bool notifyAuthorDisabled;

  /// 预取失败是否可在弹窗内重试。
  final bool retryable;

  /// 预取阶段的服务端错误（如自评、无权限）。
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  List<String> buildScoreOptions() {
    final min = minScore;
    final max = maxScore;
    if (min != null && max != null && min <= max) {
      final scores = <String>[];
      for (var score = max; score >= min; score--) {
        if (score == 0) continue;
        scores.add(_formatScore(score));
      }
      if (scores.isNotEmpty) return scores;
    }

    return scoreOptions.where((score) => score.trim() != '0').toList();
  }

  String? get preferredDefaultScore {
    final options = buildScoreOptions();
    if (options.contains('+1')) return '+1';
    if (options.contains('1')) return '1';
    return options.isNotEmpty ? options.first : null;
  }

  static String _formatScore(int score) => score > 0 ? '+$score' : '$score';

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
