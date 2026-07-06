class Thread {
  final String tid;
  final String subject;
  final String author;
  final String authorId;
  final int dateline;
  final int views;
  final int replies;
  final String fid;
  final String? lastPost;
  final String? lastPoster;

  Thread({
    required this.tid,
    required this.subject,
    required this.author,
    required this.authorId,
    required this.dateline,
    required this.views,
    required this.replies,
    required this.fid,
    this.lastPost,
    this.lastPoster,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      tid: json['tid']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      authorId: json['authorid']?.toString() ?? '',
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ?? 0,
      views: int.tryParse(json['views']?.toString() ?? '') ?? 0,
      replies: int.tryParse(json['replies']?.toString() ?? '') ?? 0,
      fid: json['fid']?.toString() ?? '',
      lastPost: json['lastpost']?.toString(),
      lastPoster: json['lastposter']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'tid': tid,
    'subject': subject,
    'author': author,
    'authorid': authorId,
    'dateline': dateline,
    'views': views,
    'replies': replies,
    'fid': fid,
  };
}
