import '../models/post.dart';

/// 楼层回复用的被引帖内存快照（非正文草稿）。
///
/// 与 Settings 里的 `compose_message_drafts` / `new_thread_drafts` /
/// `edit_post_drafts` 无关，勿混用。
class QuoteSnapshot {
  const QuoteSnapshot({
    required this.post,
    this.displayFloor = 0,
  });

  final Post post;
  final int displayFloor;
}

/// 短期内存缓存：打开 Compose 前写入；Compose 用 [peek] 读取，成功提交后再 [remove]。
///
/// 不用一次性 take，避免页面 remount / 热重载后丢失被引楼快照。
class QuoteSnapshotStore {
  QuoteSnapshotStore._();

  static final Map<String, QuoteSnapshot> _snapshots = {};
  static int _counter = 0;

  static String put(Post post, {int displayFloor = 0}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    _snapshots[id] = QuoteSnapshot(post: post, displayFloor: displayFloor);
    return id;
  }

  static QuoteSnapshot? peek(String id) => _snapshots[id];

  static void remove(String id) => _snapshots.remove(id);
}
