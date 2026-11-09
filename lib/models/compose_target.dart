/// 一次撰写写的是什么：回复、新主题或编辑。
///
/// 同一目标的草稿互相覆盖，不同目标的草稿互不可见。
sealed class ComposeTarget {
  const ComposeTarget();
}

final class ReplyTarget extends ComposeTarget {
  const ReplyTarget({required this.tid, this.reppost});

  final String tid;

  /// 被回复楼层 pid；回复主题时为 null。
  final String? reppost;

  @override
  bool operator ==(Object other) =>
      other is ReplyTarget && other.tid == tid && other.reppost == reppost;

  @override
  int get hashCode => Object.hash(ReplyTarget, tid, reppost);
}

final class NewThreadTarget extends ComposeTarget {
  const NewThreadTarget({required this.fid});

  final String fid;

  @override
  bool operator ==(Object other) =>
      other is NewThreadTarget && other.fid == fid;

  @override
  int get hashCode => Object.hash(NewThreadTarget, fid);
}

final class EditPostTarget extends ComposeTarget {
  const EditPostTarget({required this.pid});

  final String pid;

  @override
  bool operator ==(Object other) => other is EditPostTarget && other.pid == pid;

  @override
  int get hashCode => Object.hash(EditPostTarget, pid);
}
