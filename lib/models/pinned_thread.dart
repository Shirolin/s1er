class PinnedThread {
  const PinnedThread({
    required this.tid,
    required this.title,
    required this.pinnedAt,
    required this.displayOrder,
  });

  factory PinnedThread.fromJson(Map<String, dynamic> json) {
    return PinnedThread(
      tid: json['tid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      pinnedAt: int.tryParse(json['pinnedAt']?.toString() ?? '') ?? 0,
      displayOrder: int.tryParse(json['displayOrder']?.toString() ?? '') ?? 0,
    );
  }

  final String tid;
  final String title;
  final int pinnedAt;
  final int displayOrder;

  Map<String, dynamic> toJson() => {
        'tid': tid,
        'title': title,
        'pinnedAt': pinnedAt,
        'displayOrder': displayOrder,
      };

  PinnedThread copyWith({
    String? tid,
    String? title,
    int? pinnedAt,
    int? displayOrder,
  }) {
    return PinnedThread(
      tid: tid ?? this.tid,
      title: title ?? this.title,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}
