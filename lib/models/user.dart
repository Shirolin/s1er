class User {

  User({
    required this.uid,
    required this.username,
    this.avatar,
    this.groupTitle,
    this.credits = 0,
    this.posts = 0,
    this.threads = 0,
    this.friends = 0,
    this.follower = 0,
    this.following = 0,
    this.oltime = 0,
    this.deadfish = 0,
    this.combat = 0,
    this.regdate = '',
    this.groupid,
    this.signaturUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      groupTitle: json['grouptitle']?.toString() ?? json['groupTitle']?.toString(),
      credits: int.tryParse(json['credits']?.toString() ?? '') ?? 0,
      posts: int.tryParse(json['posts']?.toString() ?? '') ?? 0,
      threads: int.tryParse(json['threads']?.toString() ?? '') ?? 0,
      friends: int.tryParse(json['friends']?.toString() ?? '') ?? 0,
      follower: int.tryParse(json['follower']?.toString() ?? '') ?? 0,
      following: int.tryParse(json['following']?.toString() ?? '') ?? 0,
      oltime: int.tryParse(json['oltime']?.toString() ?? '') ?? 0,
      deadfish: int.tryParse(json['deadfish']?.toString() ?? '') ?? 0,
      combat: int.tryParse(json['combat']?.toString() ?? '') ?? 0,
      regdate: json['regdate']?.toString() ?? '',
      groupid: int.tryParse(json['groupid']?.toString() ?? ''),
    );
  }
  final String uid;
  final String username;
  final String? avatar;
  final String? groupTitle;
  final int credits;
  final int posts;
  final int threads;
  final int friends;
  final int follower;
  final int following;
  final int oltime;
  final int deadfish;
  final int combat;
  final String regdate;
  final int? groupid;
  final String? signaturUrl;

  /// 将 Discuz! avatar.php URL 转为实际可用的路径格式
  /// https://avatar.stage1st.com/avatar.php?uid=426519&size=small
  /// → https://avatar.stage1st.com/000/42/65/19_avatar_small.jpg
  static String? resolveAvatarUrl(String? avatar, {String size = 'small'}) {
    if (avatar == null || avatar.isEmpty) return null;
    if (avatar.contains('avatar.php')) {
      final uri = Uri.tryParse(avatar);
      if (uri == null) return null;
      final uid = uri.queryParameters['uid'];
      if (uid == null || uid.isEmpty) return null;
      final base = '${uri.scheme}://${uri.host}';
      final padded = uid.padLeft(9, '0');
      final seg1 = padded.substring(0, 3);
      final seg2 = padded.substring(3, 5);
      final seg3 = padded.substring(5, 7);
      final seg4 = padded.substring(7);
      return '$base/$seg1/$seg2/$seg3/${seg4}_avatar_$size.jpg';
    }
    return avatar;
  }

  User copyWith({
    String? uid,
    String? username,
    String? avatar,
    String? groupTitle,
    int? credits,
    int? posts,
    int? threads,
    int? friends,
    int? follower,
    int? following,
    int? oltime,
    int? deadfish,
    int? combat,
    String? regdate,
    int? groupid,
  }) {
    return User(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      groupTitle: groupTitle ?? this.groupTitle,
      credits: credits ?? this.credits,
      posts: posts ?? this.posts,
      threads: threads ?? this.threads,
      friends: friends ?? this.friends,
      follower: follower ?? this.follower,
      following: following ?? this.following,
      oltime: oltime ?? this.oltime,
      deadfish: deadfish ?? this.deadfish,
      combat: combat ?? this.combat,
      regdate: regdate ?? this.regdate,
      groupid: groupid ?? this.groupid,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is User &&
        other.uid == uid &&
        other.username == username &&
        other.avatar == avatar &&
        other.groupTitle == groupTitle &&
        other.credits == credits &&
        other.posts == posts &&
        other.threads == threads &&
        other.friends == friends &&
        other.follower == follower &&
        other.following == following &&
        other.oltime == oltime &&
        other.deadfish == deadfish &&
        other.combat == combat &&
        other.regdate == regdate &&
        other.groupid == groupid &&
        other.signaturUrl == signaturUrl;
  }

  @override
  int get hashCode => Object.hash(
        uid,
        username,
        avatar,
        groupTitle,
        credits,
        posts,
        threads,
        friends,
        follower,
        following,
        oltime,
        deadfish,
        combat,
        regdate,
        groupid,
        signaturUrl,
      );
}
