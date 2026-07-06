import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class PostListState {
  final List<Post> posts;
  final int currentPage;
  final int totalPages;
  final String? threadSubject;

  PostListState({
    this.posts = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.threadSubject,
  });

  PostListState copyWith({
    List<Post>? posts,
    int? currentPage,
    int? totalPages,
    String? threadSubject,
  }) {
    return PostListState(
      posts: posts ?? this.posts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      threadSubject: threadSubject ?? this.threadSubject,
    );
  }
}

final postProvider = StateNotifierProvider.family<
    PostNotifier, AsyncValue<PostListState>, String>(
  (ref, tid) => PostNotifier(
    tid: tid,
    apiService: ApiService(ref.watch(httpClientProvider)),
  ),
);

class PostNotifier extends StateNotifier<AsyncValue<PostListState>> {
  final String tid;
  final ApiService _apiService;

  PostNotifier({
    required this.tid,
    required ApiService apiService,
  })  : _apiService = apiService,
        super(const AsyncValue.loading()) {
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.getThreadDetail(tid, page: page);
      final posts = ApiService.parsePostList(result);
      final totalPages = _extractTotalPages(result);
      final subject = _extractSubject(result);
      state = AsyncValue.data(PostListState(
        posts: posts,
        currentPage: page,
        totalPages: totalPages,
        threadSubject: subject,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  int _extractTotalPages(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return 1;
    // Discuz! viewthread 返回 thread 数组中的 replies + 1 为总帖数
    final thread = variables['thread'] as Map<String, dynamic>?;
    if (thread == null) return 1;
    final replies = int.tryParse(thread['replies']?.toString() ?? '') ?? 0;
    // 每页帖数，Discuz 默认 30
    final perPage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 30;
    final totalPosts = replies + 1; // 主楼 + 回复
    return (totalPosts / perPage).ceil().clamp(1, 9999);
  }

  String? _extractSubject(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return null;
    final thread = variables['thread'] as Map<String, dynamic>?;
    return thread?['subject']?.toString();
  }

  Future<void> goToPage(int page) async {
    await _loadPage(page);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull?.currentPage ?? 1;
    await _loadPage(current);
  }
}
