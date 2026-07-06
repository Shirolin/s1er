import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/formhash_service.dart';
import 'auth_provider.dart';

final postProvider = StateNotifierProvider.family<
    PostNotifier, AsyncValue<List<Post>>, String>(
  (ref, tid) => PostNotifier(
    tid: tid,
    apiService: ApiService(ref.watch(httpClientProvider)),
    formhashService: FormhashService(httpClient: ref.watch(httpClientProvider)),
  ),
);

class PostNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  final String tid;
  final ApiService _apiService;
  final FormhashService _formhashService;
  int _currentPage = 1;

  PostNotifier({
    required this.tid,
    required ApiService apiService,
    required FormhashService formhashService,
  })  : _apiService = apiService,
        _formhashService = formhashService,
        super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.getThreadDetail(tid);
      final posts = ApiService.parsePostList(result);
      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    _currentPage++;
    try {
      final result = await _apiService.getThreadDetail(tid, page: _currentPage);
      final newPosts = ApiService.parsePostList(result);
      state.whenData((posts) {
        state = AsyncValue.data([...posts, ...newPosts]);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> getFormhash() async {
    return await _formhashService.fetchFormhash(tid);
  }
}
