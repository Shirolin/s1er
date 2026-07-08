class Thread {

  Thread({
    required this.tid,
    required this.subject,
    required this.author,
    required this.authorId,
    required this.dateline,
    required this.views,
    required this.replies,
    required this.fid,
    this.typeId,
    this.typeName,
    this.displayOrder = 0,
    this.lastPost,
    this.lastPoster,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      tid: json['tid']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      authorId: json['authorid']?.toString() ?? '',
      dateline: int.tryParse(json['dbdateline']?.toString() ?? '') ?? 0,
      views: int.tryParse(json['views']?.toString() ?? '') ?? 0,
      replies: int.tryParse(json['replies']?.toString() ?? '') ?? 0,
      fid: json['fid']?.toString() ?? '',
      typeId: json['typeid']?.toString(),
      typeName: json['typename']?.toString(),
      displayOrder: int.tryParse(json['displayorder']?.toString() ?? '') ?? 0,
      lastPost: json['lastpost']?.toString(),
      lastPoster: json['lastposter']?.toString(),
    );
  }
  final String tid;
  final String subject;
  final String author;
  final String authorId;
  final int dateline;
  final int views;
  final int replies;
  final String fid;
  final String? typeId;
  final String? typeName;
  final int displayOrder;
  final String? lastPost;
  final String? lastPoster;

  bool get isSticky => displayOrder > 0;

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
