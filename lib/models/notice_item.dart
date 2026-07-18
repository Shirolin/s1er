enum NoticeType { reply, rate, other }

enum NoticeFeed { mypost, system }

class NoticeItem {
  NoticeItem({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.summary,
    required this.dateline,
    required this.tid,
    this.pid,
    this.avatarUrl,
    this.type = NoticeType.other,
    this.isNew = false,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String summary;
  final int dateline;
  final String tid;
  final String? pid;
  final String? avatarUrl;
  final NoticeType type;
  final bool isNew;

  bool get canNavigate => tid.isNotEmpty;
}
