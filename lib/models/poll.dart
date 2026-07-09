class PollOption {
  const PollOption({
    required this.id,
    required this.text,
    required this.votes,
    required this.percent,
    required this.colorHex,
    this.isUserVote = false,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['polloptionid']?.toString() ?? '',
      text: json['polloption']?.toString() ?? '',
      votes: int.tryParse(json['votes']?.toString() ?? '') ?? 0,
      percent: double.tryParse(json['percent']?.toString() ?? '') ?? 0,
      colorHex: json['color']?.toString() ?? '6750A4',
      isUserVote: json['uservote']?.toString() == '1' ||
          json['voted']?.toString() == '1',
    );
  }

  final String id;
  final String text;
  final int votes;
  final double percent;
  final String colorHex;

  /// 当前用户是否投了此项（来自 API 扩展字段或本地缓存合并）
  final bool isUserVote;

  PollOption copyWith({bool? isUserVote}) {
    return PollOption(
      id: id,
      text: text,
      votes: votes,
      percent: percent,
      colorHex: colorHex,
      isUserVote: isUserVote ?? this.isUserVote,
    );
  }
}

class ThreadPoll {
  const ThreadPoll({
    required this.options,
    required this.expiration,
    required this.multiple,
    required this.maxChoices,
    required this.votersCount,
    required this.visibleResults,
    required this.allowVote,
    required this.remainTime,
    this.userVotedOptionIds = const [],
  });

  factory ThreadPoll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['polloptions'];
    final options = <PollOption>[];
    if (rawOptions is Map) {
      final sortedKeys = rawOptions.keys.map((k) => k.toString()).toList()
        ..sort((a, b) => int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ?? a.compareTo(b));
      for (final key in sortedKeys) {
        final value = rawOptions[key];
        if (value is Map<String, dynamic>) {
          options.add(PollOption.fromJson(value));
        } else if (value is Map) {
          options.add(PollOption.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }

    final remainRaw = json['remaintime'];
    final remainTime = <int>[];
    if (remainRaw is List) {
      for (final item in remainRaw) {
        remainTime.add(int.tryParse(item.toString()) ?? 0);
      }
    }
    while (remainTime.length < 4) {
      remainTime.add(0);
    }

    return ThreadPoll(
      options: options,
      expiration: int.tryParse(json['expirations']?.toString() ?? '') ?? 0,
      multiple: json['multiple']?.toString() == '1',
      maxChoices: int.tryParse(json['maxchoices']?.toString() ?? '') ?? 1,
      votersCount: int.tryParse(json['voterscount']?.toString() ?? '') ?? 0,
      visibleResults: json['visiblepoll']?.toString() == '1',
      allowVote: json['allowvote']?.toString() == '1',
      remainTime: remainTime,
    );
  }

  final List<PollOption> options;
  final int expiration;
  final bool multiple;
  final int maxChoices;
  final int votersCount;
  final bool visibleResults;
  final bool allowVote;
  final List<int> remainTime;
  final List<String> userVotedOptionIds;

  ThreadPoll withUserVotes(List<String> optionIds) {
    if (optionIds.isEmpty) return this;
    final voted = optionIds.toSet();
    return ThreadPoll(
      options: options
          .map((o) => o.copyWith(isUserVote: voted.contains(o.id)))
          .toList(),
      expiration: expiration,
      multiple: multiple,
      maxChoices: maxChoices,
      votersCount: votersCount,
      visibleResults: visibleResults,
      allowVote: allowVote,
      remainTime: remainTime,
      userVotedOptionIds: optionIds,
    );
  }

  bool get isExpired {
    if (remainTime.every((value) => value == 0)) return true;
    if (expiration > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiration <= now;
    }
    return false;
  }

  bool get canVote => allowVote && !isExpired;

  bool get showResults => visibleResults || !canVote;

  bool get hasUserVoted => userVotedOptionIds.isNotEmpty;

  String get remainTimeLabel {
    if (isExpired) return '投票已结束';
    final days = remainTime[0];
    final hours = remainTime[1];
    final minutes = remainTime[2];
    final seconds = remainTime[3];
    final parts = <String>[];
    if (days > 0) parts.add('$days天');
    if (hours > 0) parts.add('$hours时');
    if (minutes > 0) parts.add('$minutes分');
    if (parts.isEmpty && seconds > 0) parts.add('$seconds秒');
    if (parts.isEmpty) return '即将结束';
    return '剩余 ${parts.join('')}';
  }

  String get voteModeLabel =>
      multiple ? '多选（最多 $maxChoices 项）' : '单选';
}
