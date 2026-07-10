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

/// 短期内存缓存：打开 Compose 前写入，Compose 读取后删除。
class ComposeDraftStore {
  ComposeDraftStore._();

  static final Map<String, ComposeDraft> _drafts = {};
  static int _counter = 0;

  static String put(Post post, {int displayFloor = 0}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    _drafts[id] = ComposeDraft(post: post, displayFloor: displayFloor);
    return id;
  }

  static ComposeDraft? take(String id) => _drafts.remove(id);
}
