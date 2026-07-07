import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum_category.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

final forumListProvider =
    AsyncNotifierProvider<ForumListNotifier, List<ForumCategory>>(
  () => ForumListNotifier(),
);

class ForumListNotifier extends AsyncNotifier<List<ForumCategory>> {
  @override
  Future<List<ForumCategory>> build() async {
    final apiService = ApiService(ref.watch(httpClientProvider));
    return await apiService.getForumList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
