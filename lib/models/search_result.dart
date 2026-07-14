/// 搜索类型：主题（论坛帖）/ 用户。
enum SearchType { forum, user }

class ForumSearchHit {
  const ForumSearchHit({
    required this.tid,
    required this.title,
    this.snippet = '',
    this.forumName = '',
    this.author = '',
    this.dateline = '',
  });

  final String tid;
  final String title;
  final String snippet;
  final String forumName;
  final String author;
  final String dateline;
}

class UserSearchHit {
  const UserSearchHit({
    required this.uid,
    required this.name,
  });

  final String uid;
  final String name;
}

class ForumSearchPage {
  const ForumSearchPage({
    this.hits = const [],
    this.count = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.pageHref = '',
    this.error,
  });

  final List<ForumSearchHit> hits;
  final int count;
  final int currentPage;
  final int totalPages;

  /// 分页 URL 模板，含 `page=` 后缀（页码为空，由调用方拼接）。
  final String pageHref;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
}

class UserSearchPage {
  const UserSearchPage({
    this.hits = const [],
    this.error,
  });

  final List<UserSearchHit> hits;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
}
