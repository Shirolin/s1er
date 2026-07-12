enum FavoriteType { thread, forum }

class FavoriteItem {
  const FavoriteItem({
    required this.favid,
    required this.type,
    required this.id,
    required this.title,
    required this.dateline,
    this.forumName,
    this.views,
    this.replies,
  });

  factory FavoriteItem.fromThreadJson(Map<String, dynamic> json) {
    final tid = json['tid']?.toString() ??
        json['id']?.toString() ??
        '';
    return FavoriteItem(
      favid: json['favid']?.toString() ?? '',
      type: FavoriteType.thread,
      id: tid,
      title: _decodeHtml(json['title']?.toString() ??
          json['subject']?.toString() ??
          '',),
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ??
          int.tryParse(json['dbdateline']?.toString() ?? '') ??
          0,
      forumName: json['fname']?.toString() ?? json['forumname']?.toString(),
      views: int.tryParse(json['views']?.toString() ?? ''),
      replies: int.tryParse(json['replies']?.toString() ?? ''),
    );
  }

  factory FavoriteItem.fromForumJson(Map<String, dynamic> json) {
    final fid = json['fid']?.toString() ??
        json['id']?.toString() ??
        '';
    return FavoriteItem(
      favid: json['favid']?.toString() ?? '',
      type: FavoriteType.forum,
      id: fid,
      title: _decodeHtml(json['title']?.toString() ??
          json['name']?.toString() ??
          json['fname']?.toString() ??
          '',),
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ?? 0,
    );
  }

  final String favid;
  final FavoriteType type;
  final String id;
  final String title;
  final int dateline;
  final String? forumName;
  final int? views;
  final int? replies;

  String get membershipKey => '${type.name}:$id';

  static String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }
}

class FavoriteListResult {
  const FavoriteListResult({
    required this.items,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  static const empty = FavoriteListResult(items: []);

  final List<FavoriteItem> items;
  final int currentPage;
  final int totalPages;
}

class FavoriteMutationResult {
  const FavoriteMutationResult({this.error, this.favid});

  final String? error;
  final String? favid;

  bool get isSuccess => error == null || error!.isEmpty;
}
