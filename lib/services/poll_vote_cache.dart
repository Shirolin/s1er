import 'package:hive/hive.dart';

/// 记录用户在投票帖中的选择（API 不返回已投选项，需本地缓存）。
class PollVoteCache {
  PollVoteCache(this._box, this._uid);

  final Box _box;
  final String _uid;

  String _key(String tid) => 'poll_vote_${_uid}_$tid';

  List<String> getVotes(String tid) {
    if (tid.isEmpty || _uid.isEmpty) return const [];
    final raw = _box.get(_key(tid));
    if (raw is! List) return const [];
    return raw.map((item) => item.toString()).where((id) => id.isNotEmpty).toList();
  }

  Future<void> saveVotes(String tid, List<String> optionIds) async {
    if (tid.isEmpty || _uid.isEmpty || optionIds.isEmpty) return;
    await _box.put(_key(tid), List<String>.from(optionIds));
  }
}
