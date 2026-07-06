class User {
  final String uid;
  final String username;
  final String? avatar;
  final String? groupTitle;

  User({
    required this.uid,
    required this.username,
    this.avatar,
    this.groupTitle,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      groupTitle: json['groupTitle']?.toString(),
    );
  }
}
