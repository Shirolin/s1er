import '../utils/html_entities.dart';

class UserSpaceItem {
  UserSpaceItem({
    required this.tid,
    required this.subject,
    this.forumName,
    required this.dateline,
    this.replies = 0,
    this.views = 0,
    this.replyEntries = const [],
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

  /// 同一主题下的回复摘要。空间回复列表按主题聚合为一张卡，
  /// 论坛一次返回同一主题多条回复，拆成多张卡会重复标题与版块。
  final List<UserSpaceReplyEntry> replyEntries;

  static String _decodeHtml(String text) {
    return decodeHtmlEntities(
      text
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'),
    ).replaceAll(RegExp(r'<[^>]+>'), '');
  }
}

class UserSpaceReplyEntry {
  const UserSpaceReplyEntry({required this.pid, required this.excerpt});

  final String pid;
  final String excerpt;
}

/// 用户空间主题 / 回复列表的一页结果。
class UserSpaceListResult {
  const UserSpaceListResult({required this.items, this.totalPages = 1});
  static const empty = UserSpaceListResult(items: []);
  final List<UserSpaceItem> items;
  final int totalPages;
}
