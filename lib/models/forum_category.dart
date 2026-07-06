class ForumCategory {
  final String fid;
  final String name;
  final String description;
  final int threads;
  final int posts;
  final String? icon;

  ForumCategory({
    required this.fid,
    required this.name,
    required this.description,
    required this.threads,
    required this.posts,
    this.icon,
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      fid: json['fid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      threads: int.tryParse(json['threads']?.toString() ?? '') ?? 0,
      posts: int.tryParse(json['posts']?.toString() ?? '') ?? 0,
      icon: json['icon']?.toString(),
    );
  }
}
