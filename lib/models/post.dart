class Post {

  Post({
    required this.pid,
    required this.message,
    required this.author,
    required this.authorId,
    required this.dateline,
    required this.floor,
    this.avatar,
    this.images = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      pid: json['pid']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      authorId: json['authorid']?.toString() ?? '',
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ?? 0,
      floor: int.tryParse(json['floor']?.toString() ?? '') ?? 0,
      avatar: json['avatar']?.toString(),
    );
  }
  final String pid;
  final String message;
  final String author;
  final String authorId;
  final int dateline;
  final int floor;
  final String? avatar;
  final List<String> images;
}
