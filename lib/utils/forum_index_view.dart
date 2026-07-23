import '../models/forum_category.dart';

/// Assembled board-index view: pinned favorite shortcuts + filtered categories.
class ForumIndexView {
  const ForumIndexView({
    required this.pinned,
    required this.categories,
  });

  final List<ForumCategory> pinned;
  final List<ForumCategory> categories;
}

/// Fallback title when a favorited fid is missing from [forumindex].
typedef ForumPinTitleLookup = String Function(String fid);

/// Builds the home board-index view.
///
/// - [favoriteFidsOrdered]: favorited forum ids, newest-first.
/// - [favoriteTitleFor]: title fallback for fids not in the category tree.
/// - Hidden fids are removed from both [ForumIndexView.pinned] and categories.
/// - Categories whose visible subforums become empty are dropped.
ForumIndexView buildForumIndexView({
  required List<ForumCategory> categories,
  List<String> favoriteFidsOrdered = const [],
  ForumPinTitleLookup? favoriteTitleFor,
  Set<String> hiddenForums = const {},
}) {
  final flat = flattenForumCategories(categories);
  final pinned = <ForumCategory>[];
  final seen = <String>{};

  for (final fid in favoriteFidsOrdered) {
    if (fid.isEmpty || hiddenForums.contains(fid) || !seen.add(fid)) {
      continue;
    }
    final fromIndex = flat[fid];
    if (fromIndex != null) {
      pinned.add(_asLeaf(fromIndex));
    } else {
      final title = favoriteTitleFor?.call(fid) ?? fid;
      pinned.add(
        ForumCategory(
          fid: fid,
          name: title,
          description: '',
          threads: 0,
          posts: 0,
        ),
      );
    }
  }

  return ForumIndexView(
    pinned: pinned,
    categories: filterHiddenForums(categories, hiddenForums),
  );
}

Map<String, ForumCategory> flattenForumCategories(
  List<ForumCategory> categories,
) {
  final map = <String, ForumCategory>{};
  void walk(ForumCategory node) {
    if (node.fid.isNotEmpty) {
      map[node.fid] = node;
    }
    for (final sub in node.subforums) {
      walk(sub);
    }
  }

  for (final category in categories) {
    walk(category);
  }
  return map;
}

List<ForumCategory> filterHiddenForums(
  List<ForumCategory> categories,
  Set<String> hiddenForums,
) {
  if (hiddenForums.isEmpty) return categories;

  final result = <ForumCategory>[];
  for (final category in categories) {
    if (category.subforums.isNotEmpty) {
      final filteredSubs = [
        for (final sub in category.subforums)
          if (!hiddenForums.contains(sub.fid)) sub,
      ];
      if (filteredSubs.isEmpty) continue;
      result.add(
        ForumCategory(
          fid: category.fid,
          name: category.name,
          description: category.description,
          threads: category.threads,
          posts: category.posts,
          todayPosts: category.todayPosts,
          icon: category.icon,
          subforums: filteredSubs,
        ),
      );
    } else if (!hiddenForums.contains(category.fid)) {
      result.add(category);
    }
  }
  return result;
}

ForumCategory _asLeaf(ForumCategory forum) {
  if (forum.subforums.isEmpty) return forum;
  return ForumCategory(
    fid: forum.fid,
    name: forum.name,
    description: forum.description,
    threads: forum.threads,
    posts: forum.posts,
    todayPosts: forum.todayPosts,
    icon: forum.icon,
  );
}
