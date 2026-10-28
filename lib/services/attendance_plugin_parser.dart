/// 每日签到插件 `muanyun_053` 的页面解析。
///
/// 插件没有手机版模板，客户端取 `plugin.php?id=muanyun_053&mobile=no`：
/// - 未签到：`div.muanyun-053-actions` 里有 `form[action*="op=checkin"]`，
///   含 `input[name="checkinsubmit"]`；
/// - 已签到：同一位置只剩一个 disabled 的「今日已签到」按钮。
///
/// 判断依据是「有没有 checkin 表单」，比匹配中文文案稳。
class AttendancePluginPage {
  const AttendancePluginPage({
    required this.signedToday,
    this.consecutiveDays,
    this.totalDays,
    this.level,
    this.formhash,
    this.unavailable = false,
  });

  /// 今日是否已签到（页面存在 checkin 表单即为未签到）。
  final bool signedToday;

  /// 连续签到天数（页面可得时）。
  final int? consecutiveDays;

  /// 累计签到天数。
  final int? totalDays;

  /// 当前等级（页面头部显示的是等级名称，取不到数字时为 null）。
  final int? level;

  /// 页面下发的 formhash（提交签到必须带同一串）。
  final String? formhash;

  /// 插件被论坛停用/移除（页面提示「插件不存在或已关闭」）。
  final bool unavailable;

  static const _checkinForm = 'op=checkin';
  static const _checkinSubmitName = 'checkinsubmit';

  static AttendancePluginPage parse(String html) {
    if (html.trim().isEmpty) {
      return const AttendancePluginPage(signedToday: false);
    }
    if (html.contains('插件不存在') ||
        (html.contains('插件') && html.contains('已关闭'))) {
      return const AttendancePluginPage(signedToday: false, unavailable: true);
    }

    final hasCheckinForm =
        html.contains(_checkinForm) && html.contains(_checkinSubmitName);

    return AttendancePluginPage(
      signedToday: !hasCheckinForm,
      consecutiveDays: _statValue(html, '连续签到'),
      totalDays: _statValue(html, '累计签到'),
      level: _headerStatValue(html, '当前等级'),
      formhash: _formhash(html),
    );
  }

  /// 统计卡片：`<div class="...-stat-value">2</div>` + `<div class="...-stat-label">累计签到</div>`。
  static int? _statValue(String html, String label) => _valueBeforeLabel(
        html,
        valueClass: 'stat-value',
        label: label,
      );

  /// 头部统计：`<div class="...-header-stat-value">贝壳</div>`（等级是名称，通常非数字）。
  static int? _headerStatValue(String html, String label) => _valueBeforeLabel(
        html,
        valueClass: 'stat-value',
        label: label,
        headerStyle: true,
      );

  static int? _valueBeforeLabel(
    String html, {
    required String valueClass,
    required String label,
    bool headerStyle = false,
  }) {
    final classPattern = headerStyle
        ? '<div[^>]*class="[^"]*header-$valueClass[^"]*"[^>]*>'
        : '<div[^>]*class="[^"]*$valueClass[^"]*"[^>]*>';
    final labelClass = headerStyle ? 'header-stat-label' : 'stat-label';
    final pattern = RegExp(
      '$classPattern\\s*([^<]*?)\\s*</div>'
      '\\s*<div[^>]*class="[^"]*$labelClass[^"]*"[^>]*>\\s*$label',
    );
    final match = pattern.firstMatch(html);
    return int.tryParse(match?.group(1)?.trim() ?? '');
  }

  static String? _formhash(String html) {
    final match = RegExp(
      r'name="formhash"\s+value="([^"]+)"',
    ).firstMatch(html);
    final value = match?.group(1)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}

/// `op=checkin` 提交后的结果页解析。
class AttendanceCheckinOutcome {
  const AttendanceCheckinOutcome({
    required this.signed,
    required this.message,
    this.consecutiveDays,
  });

  final bool signed;
  final String message;
  final int? consecutiveDays;

  static AttendanceCheckinOutcome parse(String html) {
    final title = RegExp(
      r'class="[^"]*muanyun-053-message-title[^"]*"[^>]*>\s*([^<]+)',
    ).firstMatch(html)?.group(1)?.trim();

    final text = RegExp(
      r'class="[^"]*muanyun-053-message-text[^"]*"[^>]*>([\s\S]*?)</div>',
    ).firstMatch(html)?.group(1);

    final plainText = text == null ? '' : _plainMessage(text);

    final succeeded =
        (title != null && title.contains('成功')) || plainText.contains('签到成功');

    final consecutive =
        RegExp(r'连续签到\s*(\d+)\s*天').firstMatch(plainText)?.group(1);

    return AttendanceCheckinOutcome(
      signed: succeeded,
      message: plainText.isNotEmpty ? plainText : (title ?? '签到状态未知，请刷新后确认'),
      consecutiveDays: int.tryParse(consecutive ?? ''),
    );
  }

  /// 把结果页 HTML 压成纯文本，但保留服务端 `<br>` 的分行。
  ///
  /// 插件文案是三段：奖励 / （倍数说明，`span` 内）/ 连续签到，用 `<br/>` 断开。
  /// 整段压成一行会让卡片在「连续签到 N 天」中间折行（「连续签到」/「3 天」），
  /// 所以这里按 `<br>` 分段清洗，被剥掉的 `span` 留下空段则丢弃。
  static String _plainMessage(String html) {
    return html
        .split(RegExp(r'<br[^>]*>', caseSensitive: false))
        .map(
          (segment) => segment
              .replaceAll(RegExp(r'<span[\s\S]*?</span>'), ' ')
              .replaceAll(RegExp(r'<[^>]+>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .join('\n');
  }
}
