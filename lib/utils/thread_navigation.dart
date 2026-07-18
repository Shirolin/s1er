import '../config/constants.dart';
import '../models/open_scroll_target.dart';
import '../models/reading_record.dart';
import '../models/thread_destination.dart';
import '../models/thread_open_intent.dart';

/// 续读预编码标记：`?page=N&resume=1` 仍为 [ThreadOpenMode.resume]，不是强制页。
const String kThreadResumeQuery = 'resume';

/// 由回复数推算总页数（与列表卡片一致）。
int calcThreadTotalPages(
  int replies, {
  int perPage = S1Constants.postsPerPageFallback,
}) {
  final totalPosts = replies + 1;
  return (totalPosts / perPage).ceil().clamp(1, 9999);
}

/// 绝对楼层 → 当前页内 0-based 索引；越界时钳到 `[0, postCount-1]`。
int floorToPageIndex({
  required int absoluteFloor,
  required int page,
  required int perPage,
  required int postCount,
}) {
  if (postCount <= 0) return 0;
  final pageStart = (page - 1) * perPage + 1;
  final raw = absoluteFloor - pageStart;
  return raw.clamp(0, postCount - 1);
}

/// 解析打开详情时的目标页（不含 pid 定位；pid 场景需异步 locate）。
int resolveThreadInitialPage({
  required ThreadOpenIntent? intent,
  required ReadingRecord? record,
}) {
  final mode = intent?.mode ?? ThreadOpenMode.resume;

  if (mode == ThreadOpenMode.page) {
    final explicitPage = intent?.page;
    if (explicitPage != null && explicitPage >= 1) {
      return explicitPage;
    }
  }

  if (record != null) {
    final liveReplies = intent?.liveTotalReplies ?? record.totalReplies;
    final target = record.resolveOpenPage(liveReplies);
    if (target > 1) {
      return target;
    }
  }

  return 1;
}

/// resume 打开落点：B3 新回复首楼所在页 → 页顶；否则 → 滚到 [ReadingRecord.lastReadFloor]。
OpenScrollTarget resolveResumeScrollTarget({
  required ReadingRecord? record,
  required int loadedPage,
  required int liveTotalReplies,
  int? perPage,
}) {
  if (record == null) {
    return const ScrollToPageTop();
  }

  final ppp =
      (perPage != null && perPage > 0) ? perPage : record.effectivePerPage;
  final livePages = calcThreadTotalPages(liveTotalReplies, perPage: ppp);

  if (record.isFinished && record.hasNewReplies(liveTotalReplies)) {
    final b3Page =
        pageForFloor(record.totalPosts + 1, perPage: ppp).clamp(1, livePages);
    if (loadedPage == b3Page) {
      return const ScrollToPageTop();
    }
  }

  final floor = record.lastReadFloor;
  if (floor <= 0) {
    return const ScrollToPageTop();
  }
  return ScrollToFloor(floor);
}

/// Destination ↔ URI 编解码。
abstract final class ThreadRouteCodec {
  static const forumThreadIdQuery = 'tid';
  static const forumThreadPageQuery = 'threadPage';

  static Uri encode(ThreadDestination destination) {
    final tid = destination.tid;
    switch (destination) {
      case ResumeThread():
        return Uri(path: '/thread/$tid');
      case ThreadPage(:final page):
        return Uri(
          path: '/thread/$tid',
          queryParameters: {'page': '$page'},
        );
      case ThreadPost(:final pid):
        return Uri(
          path: '/thread/$tid',
          queryParameters: {'pid': pid},
        );
    }
  }

  /// 将 destination 编为 go_router 可用的 location 字符串。
  static String encodePath(ThreadDestination destination) =>
      encode(destination).toString();

  /// 将详情目标编码为论坛双栏路由。列表页码不占用 `page`，避免歧义。
  static String encodeForumPath(
    String fid,
    ThreadDestination destination, {
    int? resumePageHint,
  }) {
    final query = <String, String>{forumThreadIdQuery: destination.tid};
    switch (destination) {
      case ThreadPage(:final page):
        query[forumThreadPageQuery] = '$page';
      case ThreadPost(:final pid):
        query['pid'] = pid;
      case ResumeThread():
        if (resumePageHint != null && resumePageHint > 1) {
          query[forumThreadPageQuery] = '$resumePageHint';
          query[kThreadResumeQuery] = '1';
        }
    }
    return Uri(path: '/forum/$fid', queryParameters: query).toString();
  }

  /// 从论坛双栏路由解析详情 Intent。
  static ThreadOpenIntent? forumIntentFromUri(Uri uri) {
    final tid = uri.queryParameters[forumThreadIdQuery];
    if (tid == null || tid.isEmpty) return null;
    final pid = uri.queryParameters['pid'];
    if (pid != null && pid.isNotEmpty) return toIntent(ThreadPost(tid, pid));
    final page = int.tryParse(uri.queryParameters[forumThreadPageQuery] ?? '');
    final resume = uri.queryParameters[kThreadResumeQuery] == '1';
    if (page != null && page >= 1 && !resume) {
      return toIntent(ThreadPage(tid, page));
    }
    return toIntent(ResumeThread(tid), resumePageHint: resume ? page : null);
  }

  /// 从路由 URI 解码。非法 / 缺失 page → resume。
  ///
  /// 优先级：`pid` > 强制 `page` > `page`+`resume=1`（续读提示）> 裸路径 resume。
  static ThreadDestination decode(Uri uri, {required String tid}) {
    final pid = uri.queryParameters['pid'];
    if (pid != null && pid.isNotEmpty) {
      return ThreadPost(tid, pid);
    }

    final pageStr = uri.queryParameters['page'];
    final page = pageStr != null ? int.tryParse(pageStr) : null;
    final isResumeHint = uri.queryParameters[kThreadResumeQuery] == '1';

    if (page != null && page >= 1 && !isResumeHint) {
      return ThreadPage(tid, page);
    }

    return ResumeThread(tid);
  }

  static ThreadOpenIntent toIntent(
    ThreadDestination destination, {
    int? liveTotalReplies,
    int? resumePageHint,
  }) {
    switch (destination) {
      case ResumeThread():
        return ThreadOpenIntent.resume(
          page: resumePageHint,
          liveTotalReplies: liveTotalReplies,
        );
      case ThreadPage(:final page):
        return ThreadOpenIntent.page(page, liveTotalReplies: liveTotalReplies);
      case ThreadPost(:final pid):
        return ThreadOpenIntent.post(pid, liveTotalReplies: liveTotalReplies);
    }
  }

  /// 从完整路由 URI 生成 Intent（含 `resume=1` 预解析页提示）。
  static ThreadOpenIntent intentFromUri(Uri uri, {required String tid}) {
    final destination = decode(uri, tid: tid);
    final pageStr = uri.queryParameters['page'];
    final page = pageStr != null ? int.tryParse(pageStr) : null;
    final resumeHint = uri.queryParameters[kThreadResumeQuery] == '1'
        ? (page != null && page >= 1 ? page : null)
        : null;
    return toIntent(destination, resumePageHint: resumeHint);
  }

  /// 续读并预带页码（防闪页）：`/thread/{tid}?page=N&resume=1`。
  static String encodeResumeWithPageHint(String tid, int page) {
    if (page <= 1) {
      return encodePath(ResumeThread(tid));
    }
    return Uri(
      path: '/thread/$tid',
      queryParameters: {
        'page': '$page',
        kThreadResumeQuery: '1',
      },
    ).toString();
  }
}

/// 根据阅读记录构建帖子详情路由路径（resume；页 > 1 时带 resume 标记预编码）。
String buildThreadDetailPath(
  String tid, {
  ReadingRecord? record,
  int? liveTotalReplies,
}) {
  final replies = liveTotalReplies ?? record?.totalReplies;
  final targetPage =
      record != null && replies != null ? record.resolveOpenPage(replies) : 1;
  return ThreadRouteCodec.encodeResumeWithPageHint(tid, targetPage);
}
