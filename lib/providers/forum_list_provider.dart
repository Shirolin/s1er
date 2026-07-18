import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum_category.dart';
import 'api_service_provider.dart';

final forumListProvider =
    AsyncNotifierProvider<ForumListNotifier, List<ForumCategory>>(
  () => ForumListNotifier(),
);

class ForumListNotifier extends AsyncNotifier<List<ForumCategory>> {
  @override
  Future<List<ForumCategory>> build() async {
    final apiService = ref.watch(apiServiceProvider);
    return apiService.getForumList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
