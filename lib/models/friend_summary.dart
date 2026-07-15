import 'user.dart';

class FriendSummary {
  const FriendSummary({required this.uid, required this.username});

  factory FriendSummary.fromJson(Map<String, dynamic> json) {
    return FriendSummary(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
    );
  }

  final String uid;
  final String username;

  String? get avatarUrl =>
      User.resolveAvatarUrl('https://avatar.stage1st.com/avatar.php?uid=$uid');
}

class FriendListResult {
  const FriendListResult({required this.items, this.count});

  static const empty = FriendListResult(items: []);

  final List<FriendSummary> items;
  final int? count;
}
