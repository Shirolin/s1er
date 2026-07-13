import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/fid_forum_name.dart';
import 'forum_list_provider.dart';

final fidToForumNameMapProvider = Provider<Map<String, String>>((ref) {
  final categories = ref.watch(
    forumListProvider.select((value) => value.asData?.value),
  );
  return buildFidToForumNameMap(categories);
});

final forumNameProvider = Provider.family<String?, String>((ref, fid) {
  return ref.watch(fidToForumNameMapProvider)[fid];
});
