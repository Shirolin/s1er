/// 阅读记录 / 阅读进度模型（纯 Dart，不依赖 Flutter）。
///
/// 存储于 Hive Box `reading_history`，value 为 [toJson] 的 Map。
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

  /// 最后阅读页码（1-based）
  final int lastReadPage;

  /// 最后阅读的绝对楼层（1-based，跨页累计）；仅用于展示，不参与判定。
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

  /// 阅读进度 0.0 ~ 1.0（页级，见计划 C2）。
  double get progress =>
      totalPages > 0 ? (lastReadPage / totalPages).clamp(0.0, 1.0) : 0.0;

  /// 是否读完（页级判定，`totalPages` 已 clamp(1,…)）。
  ///
  /// 说明：数据流只知「已加载到第几页」，故按页级判定。0 回复帖
  /// (`totalReplies == 0`) 亦满足 `totalPages == 1 && lastReadPage == 1 ⇒ 已读`。
  bool get isFinished => lastReadPage >= totalPages;

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
