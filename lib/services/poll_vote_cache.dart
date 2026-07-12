import 'app_local_data.dart';

/// 记录用户在投票帖中的选择（API 不返回已投选项，需本地缓存）。
class PollVoteCache {
  PollVoteCache(this._local, this._uid);

  final AppLocalData _local;
  final String _uid;

  String _key(String tid) => '${_uid}_$tid';

  List<String> getVotes(String tid) {
    if (tid.isEmpty || _uid.isEmpty) return const [];
    return List<String>.from(_local.pollVotes[_key(tid)] ?? const []);
  }

  Future<void> saveVotes(String tid, List<String> optionIds) async {
    if (tid.isEmpty || _uid.isEmpty || optionIds.isEmpty) return;
    _local.putPollVotes(_uid, tid, optionIds);
  }

  Future<void> clearAll() async {
    if (_uid.isEmpty) return;
    await _local.clearPollVotes(_uid);
  }
}
