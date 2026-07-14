import '../config/constants.dart';
import '../models/reading_record.dart';
import '../models/thread_open_intent.dart';

/// 由回复数推算总页数（与列表卡片一致）。
int calcThreadTotalPages(
  int replies, {
  int perPage = S1Constants.postsPerPageFallback,
}) {
  final totalPosts = replies + 1;
  return (totalPosts / perPage).ceil().clamp(1, 9999);
}

/// 解析打开详情时的目标页（不含 pid 定位；pid 场景需异步 locate）。
int resolveThreadInitialPage({
  required ThreadOpenIntent? intent,
  required ReadingRecord? record,
}) {
  final explicitPage = intent?.initialPage;
  if (explicitPage != null && explicitPage > 1) {
    return explicitPage;
  }

  if (record != null) {
    final live = intent?.liveTotalPages ?? record.totalPages;
    final target = record.resolveOpenPage(live);
    if (target > 1) {
      return target;
    }
  }

  return 1;
}

/// 根据阅读记录构建帖子详情路由路径。
String buildThreadDetailPath(
  String tid, {
  ReadingRecord? record,
  int? liveTotalPages,
}) {
  final pages = liveTotalPages ?? record?.totalPages;
  final targetPage =
      record != null && pages != null ? record.resolveOpenPage(pages) : 1;
  if (targetPage <= 1) {
    return '/thread/$tid';
  }
  return '/thread/$tid?page=$targetPage';
}
