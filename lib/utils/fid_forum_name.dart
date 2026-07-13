import '../models/forum_category.dart';

Map<String, String> buildFidToForumNameMap(List<ForumCategory>? categories) {
  if (categories == null) return const {};
  final map = <String, String>{};
  for (final category in categories) {
    map[category.fid] = category.name;
    for (final sub in category.subforums) {
      map[sub.fid] = sub.name;
    }
  }
  return map;
}
