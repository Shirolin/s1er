import 'user.dart';
import 'post_attachment.dart';

class Post {
  Post({
    required this.pid,
    required this.message,
    required this.author,
    required this.authorId,
    required this.dateline,
    required this.floor,
    this.isFirst = false,
    this.avatar,
    this.images = const [],
    this.attachments = const {},
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      pid: json['pid']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      authorId: json['authorid']?.toString() ?? '',
      dateline: int.tryParse(json['dbdateline']?.toString() ?? '') ?? 0,
      floor: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      isFirst: json['first']?.toString() == '1',
      avatar: User.resolveAvatarUrl(
        'https://avatar.stage1st.com/avatar.php?uid=${json['authorid']}&size=small',
      ),
      attachments: PostAttachment.parseMap(json['attachments']),
    );
  }
  final String pid;
  final String message;
  final String author;
  final String authorId;
  final int dateline;
  final int floor;
  final bool isFirst;
  final String? avatar;
  final List<String> images;

  /// 楼层附件（key 为 aid）；正文 `[attach]` / `[attachimg]` 引用它。
  final Map<String, PostAttachment> attachments;
}
