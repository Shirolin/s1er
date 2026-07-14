class UserSpaceItem {
  UserSpaceItem({
    required this.tid,
    required this.subject,
    this.forumName,
    required this.dateline,
    this.replies = 0,
    this.views = 0,
    this.replyExcerpt,
    this.pid,
    this.isReply = false,
  });

  factory UserSpaceItem.fromThreadJson(Map<String, dynamic> json) {
    return UserSpaceItem(
      tid: json['tid']?.toString() ?? '',
      subject: _decodeHtml(json['subject']?.toString() ?? ''),
      forumName: json['fname']?.toString() ?? json['forumname']?.toString(),
      dateline: int.tryParse(json['dbdateline']?.toString() ?? '') ?? 0,
      replies: int.tryParse(json['replies']?.toString() ?? '') ?? 0,
      views: int.tryParse(json['views']?.toString() ?? '') ?? 0,
    );
  }

  final String tid;
  final String subject;
  final String? forumName;
  final int dateline;
  final int replies;
  final int views;
  final String? replyExcerpt;
  final String? pid;
  final bool isReply;

  static String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }
}
