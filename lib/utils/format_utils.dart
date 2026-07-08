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
  return '${dt.year % 100}/$month/$day';
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
