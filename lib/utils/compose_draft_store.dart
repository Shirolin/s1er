import '../models/post.dart';

/// 楼层回复草稿（引用目标帖快照）。
class ComposeDraft {
  const ComposeDraft({
    required this.post,
    this.displayFloor = 0,
  });

  final Post post;
  final int displayFloor;
}

/// 短期内存缓存：打开 Compose 前写入；Compose 用 [peek] 读取，成功提交后再 [remove]。
///
/// 不用一次性 [take]，避免页面 remount / 热重载后丢失被引楼快照，导致引用退回无跳转的 helper 片段。
class ComposeDraftStore {
  ComposeDraftStore._();

  static final Map<String, ComposeDraft> _drafts = {};
  static int _counter = 0;

  static String put(Post post, {int displayFloor = 0}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    _drafts[id] = ComposeDraft(post: post, displayFloor: displayFloor);
    return id;
  }

  static ComposeDraft? peek(String id) => _drafts[id];

  static void remove(String id) => _drafts.remove(id);

  /// 兼容旧调用：读取并删除。
  static ComposeDraft? take(String id) => _drafts.remove(id);
}
