/// 列表回复数等需完整展示的计数（不缩写、不加千分位逗号）。
String formatFullCount(int n) {
  if (n < 0) return '0';
  return '$n';
}

/// 数字缩写：12345 → 1.2万，256823 → 25.7万，318 → 318
String formatCount(int n) {
  if (n >= 100000) return '${(n / 10000).toStringAsFixed(0)}万';
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

/// 相对时间（紧凑）：用于列表行，如 "刚刚"、"3分前"、"5时前"、"3天前"、"12-01"
String formatTimeAgo(int dateline) {
  if (dateline <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(dateline * 1000);
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分前';
  if (diff.inDays < 1) return '${diff.inHours}时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';

  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  if (dt.year == now.year) return '$month-$day';
  // 与当年的 `07-22` 保持同一分隔符；`25/06/17` 既混用分隔符又容易被读成月日。
  return '${dt.year}-$month-$day';
}

/// 完整日期时间：用于详情页，如 "2024-11-12 19:01"
String formatDateTime(int dateline) {
  if (dateline <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(dateline * 1000);
  final now = DateTime.now();

  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  if (dt.year == now.year) return '$month-$day $hour:$minute';
  return '${dt.year}-$month-$day $hour:$minute';
}

/// 归一化引用头里的日期文本（源帖常写 `2026-11-7 16:44`），
/// 补齐为 `2026-11-07 16:44`；保留年份（引文可能来自往年）。
/// 无法识别时原样返回，避免吞掉非标准写法。
String formatLooseDateTime(String raw) {
  final text = raw.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::\d{2})?$',
  ).firstMatch(text);
  if (match == null) return text;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59) {
    return text;
  }

  String two(int value) => value.toString().padLeft(2, '0');
  return '$year-${two(month)}-${two(day)} ${two(hour)}:${two(minute)}';
}

/// 注册时间：支持 Unix 时间戳或已有日期字符串，输出紧凑格式。
String formatRegDate(String regdate) {
  if (regdate.isEmpty) return '';
  final ts = int.tryParse(regdate);
  if (ts != null && ts > 0) return formatDateTime(ts);

  final trimmed = regdate.trim();
  // API 可能返回 "2019-3-19 11:02:33" 等格式，去掉秒数。
  final noSeconds = RegExp(r'^(.+:\d{2}):\d{2}$').firstMatch(trimmed);
  if (noSeconds != null) return noSeconds.group(1)!;
  return trimmed;
}
