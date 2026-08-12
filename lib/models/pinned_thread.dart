class PinnedThread {
  const PinnedThread({
    required this.tid,
    required this.title,
    required this.pinnedAt,
    required this.displayOrder,
    this.lastKnownReplies,
    this.lastSeenReplies,
    this.lastFetchedAt,
  });

  factory PinnedThread.fromJson(Map<String, dynamic> json) {
    return PinnedThread(
      tid: json['tid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      pinnedAt: int.tryParse(
            (json['pinnedAt'] ?? json['pinned_at'])?.toString() ?? '',
          ) ??
          0,
      displayOrder: int.tryParse(
            (json['displayOrder'] ?? json['display_order'])?.toString() ?? '',
          ) ??
          0,
      lastKnownReplies: _parseOptionalInt(
        json['lastKnownReplies'] ?? json['last_known_replies'],
      ),
      lastSeenReplies: _parseOptionalInt(
        json['lastSeenReplies'] ?? json['last_seen_replies'],
      ),
      lastFetchedAt: _parseOptionalInt(
        json['lastFetchedAt'] ?? json['last_fetched_at'],
      ),
    );
  }

  final String tid;
  final String title;
  final int pinnedAt;
  final int displayOrder;

  /// 最近一次从版块列表 / 打开详情顺带看到的回复数（live）。
  final int? lastKnownReplies;

  /// 上次打开该置顶帖时记下的回复数（对齐 S1-Next lastCountWhenView）。
  final int? lastSeenReplies;

  /// 上次按 tid 主动拉取回复数的时间（秒）；用于单帖 CD。
  final int? lastFetchedAt;

  Map<String, dynamic> toJson() => {
        'tid': tid,
        'title': title,
        'pinnedAt': pinnedAt,
        'displayOrder': displayOrder,
        if (lastKnownReplies != null) 'lastKnownReplies': lastKnownReplies,
        if (lastSeenReplies != null) 'lastSeenReplies': lastSeenReplies,
        if (lastFetchedAt != null) 'lastFetchedAt': lastFetchedAt,
      };

  PinnedThread copyWith({
    String? tid,
    String? title,
    int? pinnedAt,
    int? displayOrder,
    int? lastKnownReplies,
    bool clearLastKnownReplies = false,
    int? lastSeenReplies,
    bool clearLastSeenReplies = false,
    int? lastFetchedAt,
    bool clearLastFetchedAt = false,
  }) {
    return PinnedThread(
      tid: tid ?? this.tid,
      title: title ?? this.title,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      displayOrder: displayOrder ?? this.displayOrder,
      lastKnownReplies: clearLastKnownReplies
          ? null
          : (lastKnownReplies ?? this.lastKnownReplies),
      lastSeenReplies: clearLastSeenReplies
          ? null
          : (lastSeenReplies ?? this.lastSeenReplies),
      lastFetchedAt:
          clearLastFetchedAt ? null : (lastFetchedAt ?? this.lastFetchedAt),
    );
  }

  static int? _parseOptionalInt(Object? raw) {
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }
}

/// 对齐 S1-Next：距上次打开后的新增回复数；缺一侧或无新增时返回 null。
int? pinnedNewReplyCount({
  required int? liveReplies,
  required int? lastSeenReplies,
}) {
  if (liveReplies == null || lastSeenReplies == null) return null;
  final delta = liveReplies - lastSeenReplies;
  return delta > 0 ? delta : null;
}
