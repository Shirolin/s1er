class ForumCategory {
  ForumCategory({
    required this.fid,
    required this.name,
    required this.description,
    required this.threads,
    required this.posts,
    this.todayPosts = 0,
    this.icon,
    this.subforums = const [],
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    final subforumList = json['sublist'] as List? ?? [];
    return ForumCategory(
      fid: json['fid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      threads: int.tryParse(json['threads']?.toString() ?? '') ?? 0,
      posts: int.tryParse(json['posts']?.toString() ?? '') ?? 0,
      todayPosts: int.tryParse(json['todayposts']?.toString() ?? '') ?? 0,
      icon: json['icon']?.toString(),
      subforums: subforumList
          .map((f) => ForumCategory.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
  final String fid;
  final String name;
  final String description;
  final int threads;
  final int posts;
  final int todayPosts;
  final String? icon;
  final List<ForumCategory> subforums;
}
