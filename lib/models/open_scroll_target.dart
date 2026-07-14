/// 帖子详情首屏一次性滚动落点（由 [PostListState] 携带，Screen 消费一次）。
sealed class OpenScrollTarget {
  const OpenScrollTarget();
}

/// 滚到指定 pid；[highlight] 为 true 时高亮该楼。
final class ScrollToPid extends OpenScrollTarget {
  const ScrollToPid(this.pid, {this.highlight = true});

  final String pid;
  final bool highlight;
}

/// 滚到绝对楼层（1-based，跨页累计）；用于 resume 楼级落点。
final class ScrollToFloor extends OpenScrollTarget {
  const ScrollToFloor(this.absoluteFloor);

  final int absoluteFloor;
}

/// 落到当前页顶部（强制页 / B3 新页）。
final class ScrollToPageTop extends OpenScrollTarget {
  const ScrollToPageTop();
}
