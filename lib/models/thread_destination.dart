/// 帖子详情打开目标（纯 Dart；与 URL 一一对应）。
sealed class ThreadDestination {
  const ThreadDestination(this.tid);

  final String tid;
}

/// 按本地阅读记录续读（页 + 楼级落点）；URI 为裸 `/thread/{tid}`。
final class ResumeThread extends ThreadDestination {
  const ResumeThread(super.tid);
}

/// 强制打开指定页（含 page=1），覆盖续读；落到页顶。
final class ThreadPage extends ThreadDestination {
  const ThreadPage(super.tid, this.page)
      : assert(page >= 1, 'page must be >= 1');

  final int page;
}

/// 定位到指定回复 pid 并高亮。
final class ThreadPost extends ThreadDestination {
  const ThreadPost(super.tid, this.pid);

  final String pid;
}
