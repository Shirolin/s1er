import 'user.dart';

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
      dateline: int.tryParse(json['dbdateline']?.toString() ?? '') ?? 0,
      floor: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      avatar: User.resolveAvatarUrl(
        'https://avatar.stage1st.com/avatar.php?uid=${json['authorid']}&size=small',
      ),
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
