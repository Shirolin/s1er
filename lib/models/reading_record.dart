import '../config/constants.dart';

/// 绝对楼层 → 1-based 页码。
int pageForFloor(int absoluteFloor, {required int perPage}) {
  if (absoluteFloor <= 0 || perPage <= 0) return 1;
  return ((absoluteFloor - 1) ~/ perPage) + 1;
}

/// 阅读记录 / 阅读进度模型（纯 Dart，不依赖 Flutter）。
///
/// 存储于本地 Drift 表 `reading_histories`，内存镜像为 [toJson] 的 Map。
/// 进度 / 已读 / 开页一律以 [lastReadFloor] 为准；[lastReadPage] 仅作存储冗余。
class ReadingRecord {
  ReadingRecord({
    required this.tid,
    required this.subject,
    required this.author,
    required this.fid,
    required this.lastReadPage,
    required this.lastReadFloor,
    required this.totalPages,
    required this.totalReplies,
    required this.perPage,
    required this.lastReadAt,
    required this.firstReadAt,
    this.readCount = 1,
  });

  factory ReadingRecord.fromJson(Map<String, dynamic> json) {
    return ReadingRecord(
      tid: json['tid']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      fid: json['fid']?.toString() ?? '',
      lastReadPage: (json['lastReadPage'] as num?)?.toInt() ?? 1,
      lastReadFloor: (json['lastReadFloor'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      totalReplies: (json['totalReplies'] as num?)?.toInt() ?? 0,
      perPage: (json['perPage'] as num?)?.toInt() ?? 0,
      lastReadAt: (json['lastReadAt'] as num?)?.toInt() ?? 0,
      firstReadAt: (json['firstReadAt'] as num?)?.toInt() ?? 0,
      readCount: (json['readCount'] as num?)?.toInt() ?? 1,
    );
  }

  final String tid;
  final String subject;
  final String author;
  final String fid;

  /// 最后阅读页码（1-based）；存储冗余，不参与进度/已读/开页判定。
  final int lastReadPage;

  /// 最后阅读的绝对楼层（1-based，跨页累计）；进度与 resume 落点的权威字段。
  final int lastReadFloor;

  /// 帖子总页数（缓存）
  final int totalPages;

  /// 帖子总回复数（缓存）
  final int totalReplies;

  /// 每页帖数（来自 API `ppp`，缓存）
  final int perPage;

  /// 最后阅读时间（millisecondsSinceEpoch）
  final int lastReadAt;

  /// 首次阅读时间（millisecondsSinceEpoch）
  final int firstReadAt;

  /// 进入详情页次数（翻页不计）
  final int readCount;

  /// 缓存总楼数（主楼 + 回复）。
  int get totalPosts => totalReplies + 1;

  int get effectivePerPage =>
      perPage > 0 ? perPage : S1Constants.postsPerPageFallback;

  /// 阅读进度 0.0 ~ 1.0（楼级）。
  double get progress =>
      totalPosts > 0 ? (lastReadFloor / totalPosts).clamp(0.0, 1.0) : 0.0;

  /// 是否读完（楼级：已读到缓存总楼）。
  ///
  /// 0 回复帖：`totalPosts == 1 && lastReadFloor >= 1 ⇒ 已读`。
  /// 仅反映**上次写入时**的缓存；列表卡片请用 [isFinishedAt] 对照实时回复数。
  bool get isFinished => lastReadFloor >= totalPosts;

  /// 相对实时回复数，是否已读完（用于列表/API 更新后的展示）。
  bool isFinishedAt(int liveTotalReplies) {
    final livePosts = liveTotalReplies + 1;
    return livePosts > 0 && lastReadFloor >= livePosts;
  }

  /// 缓存回复数是否落后于实时值（有新回复）。
  bool hasNewReplies(int liveTotalReplies) => liveTotalReplies > totalReplies;

  /// 相对实时回复数的进度（列表卡片进度条用）。
  double progressAt(int liveTotalReplies) {
    final livePosts = liveTotalReplies + 1;
    return livePosts > 0 ? (lastReadFloor / livePosts).clamp(0.0, 1.0) : 0.0;
  }

  /// 打开详情时应落地的页码（1-based），由楼层推算。
  ///
  /// [liveTotalReplies] 须来自列表 `thread.replies` 或详情 API。
  int resolveOpenPage(int liveTotalReplies, {int? perPage}) {
    final ppp = (perPage != null && perPage > 0) ? perPage : effectivePerPage;
    final livePosts = liveTotalReplies + 1;
    final livePages =
        livePosts > 0 ? (livePosts / ppp).ceil().clamp(1, 9999) : 1;

    if (!isFinished) {
      return pageForFloor(lastReadFloor, perPage: ppp).clamp(1, livePages);
    }

    if (hasNewReplies(liveTotalReplies)) {
      // 首个未读楼 = 缓存 totalPosts + 1
      final unreadFloor =
          (lastReadFloor > totalPosts ? lastReadFloor : totalPosts) + 1;
      return pageForFloor(unreadFloor, perPage: ppp).clamp(1, livePages);
    }

    return livePages;
  }

  Map<String, dynamic> toJson() => {
        'tid': tid,
        'subject': subject,
        'author': author,
        'fid': fid,
        'lastReadPage': lastReadPage,
        'lastReadFloor': lastReadFloor,
        'totalPages': totalPages,
        'totalReplies': totalReplies,
        'perPage': perPage,
        'lastReadAt': lastReadAt,
        'firstReadAt': firstReadAt,
        'readCount': readCount,
      };

  ReadingRecord copyWith({
    String? subject,
    String? author,
    String? fid,
    int? lastReadPage,
    int? lastReadFloor,
    int? totalPages,
    int? totalReplies,
    int? perPage,
    int? lastReadAt,
    int? firstReadAt,
    int? readCount,
  }) {
    return ReadingRecord(
      tid: tid,
      subject: subject ?? this.subject,
      author: author ?? this.author,
      fid: fid ?? this.fid,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      lastReadFloor: lastReadFloor ?? this.lastReadFloor,
      totalPages: totalPages ?? this.totalPages,
      totalReplies: totalReplies ?? this.totalReplies,
      perPage: perPage ?? this.perPage,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      firstReadAt: firstReadAt ?? this.firstReadAt,
      readCount: readCount ?? this.readCount,
    );
  }
}
