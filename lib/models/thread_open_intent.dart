/// 帖子详情页一次性打开意图（由路由或入口注入，仅首屏 [PostNotifier.build] 消费）。
class ThreadOpenIntent {
  const ThreadOpenIntent({
    this.initialPage,
    this.targetPid,
    this.liveTotalPages,
  });

  /// 显式目标页（来自 `?page=` 或入口预解析）。
  final int? initialPage;

  /// 目标楼层 pid（来自 `?pid=`）。
  final String? targetPid;

  /// 入口已知的实时总页数（如列表 `thread.replies` 推算），用于续读 B3 判定。
  final int? liveTotalPages;
}
