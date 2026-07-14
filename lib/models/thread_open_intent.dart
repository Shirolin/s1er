/// 帖子详情打开模式（由路由解码或入口注入）。
enum ThreadOpenMode {
  /// 按本地阅读记录续读（可附带预解析 page 提示，仍为续读）。
  resume,

  /// 强制指定页，覆盖续读。
  page,

  /// 按 pid 定位楼层。
  post,
}

/// 帖子详情页一次性打开意图（由路由注入，仅首屏 [PostNotifier.build] 消费）。
class ThreadOpenIntent {
  const ThreadOpenIntent({
    required this.mode,
    this.page,
    this.pid,
    this.liveTotalPages,
  });

  /// 裸 `/thread/{tid}` 或带 `resume=1` 的续读。
  const ThreadOpenIntent.resume({
    this.page,
    this.liveTotalPages,
  })  : mode = ThreadOpenMode.resume,
        pid = null;

  /// 强制 `?page=`（含 page=1）。
  const ThreadOpenIntent.page(this.page, {this.liveTotalPages})
      : mode = ThreadOpenMode.page,
        pid = null;

  /// `?pid=` 定位。
  const ThreadOpenIntent.post(this.pid, {this.liveTotalPages})
      : mode = ThreadOpenMode.post,
        page = null;

  final ThreadOpenMode mode;

  /// 强制页，或 resume 预解析提示页（仍须再跑 B1–B3 / 楼级）。
  final int? page;

  /// 目标楼层 pid。
  final String? pid;

  /// 入口已知的实时总页数（如列表 `thread.replies` 推算），用于续读 B3 判定。
  final int? liveTotalPages;
}
