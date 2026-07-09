import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class PostListState {

  PostListState({
    this.posts = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.threadSubject,
    this.threadFid,
    this.perPage = S1Constants.postsPerPageFallback,
    this.totalReplies = 0,
  });
  final List<Post> posts;
  final int currentPage;
  final int totalPages;
  final String? threadSubject;
  final String? threadFid;

  /// 每页帖数（来自 API `ppp`，缺省用 fallback 40）
  final int perPage;

  /// 帖子总回复数（来自 API `thread.replies`）
  final int totalReplies;

  PostListState copyWith({
    List<Post>? posts,
    int? currentPage,
    int? totalPages,
    String? threadSubject,
    String? threadFid,
    int? perPage,
    int? totalReplies,
  }) {
    return PostListState(
      posts: posts ?? this.posts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      threadSubject: threadSubject ?? this.threadSubject,
      threadFid: threadFid ?? this.threadFid,
      perPage: perPage ?? this.perPage,
      totalReplies: totalReplies ?? this.totalReplies,
    );
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(httpClientProvider));
});

final postProvider = StateNotifierProvider.family<
    PostNotifier, AsyncValue<PostListState>, String>(
  (ref, tid) => PostNotifier(
    tid: tid,
    apiService: ref.watch(apiServiceProvider),
  ),
);

class PostNotifier extends StateNotifier<AsyncValue<PostListState>> {

  PostNotifier({
    required this.tid,
    required ApiService apiService,
  })  : _apiService = apiService,
        super(const AsyncValue.loading()) {
    _loadPage(1);
  }
  final String tid;
  final ApiService _apiService;

  Future<void> _loadPage(int page) async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.getThreadDetail(tid, page: page);
      final posts = ApiService.parsePostList(result);

      // 统一提取 variables / thread，避免重复遍历 JSON
      final variables = result['Variables'] as Map<String, dynamic>? ?? {};
      final thread = variables['thread'] as Map<String, dynamic>? ?? {};
      // 每页帖数：API 字段 ppp（viewthread），拿不到时用 fallback 40（不是 30）
      final perPage = int.tryParse(variables['ppp']?.toString() ?? '') ??
          S1Constants.postsPerPageFallback;
      final totalReplies = int.tryParse(thread['replies']?.toString() ?? '') ?? 0;
      final totalPosts = totalReplies + 1; // 主楼 + 回复
      final totalPages = (totalPosts / perPage).ceil().clamp(1, 9999);

      state = AsyncValue.data(PostListState(
        posts: posts,
        currentPage: page,
        totalPages: totalPages,
        threadSubject: thread['subject']?.toString(),
        threadFid: thread['fid']?.toString(),
        perPage: perPage,
        totalReplies: totalReplies,
      ),);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> goToPage(int page) async {
    await _loadPage(page);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull?.currentPage ?? 1;
    await _loadPage(current);
  }
}
