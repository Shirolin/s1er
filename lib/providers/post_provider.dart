import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });
  final List<Post> posts;
  final int currentPage;
  final int totalPages;
  final String? threadSubject;
  final String? threadFid;

  PostListState copyWith({
    List<Post>? posts,
    int? currentPage,
    int? totalPages,
    String? threadSubject,
    String? threadFid,
  }) {
    return PostListState(
      posts: posts ?? this.posts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      threadSubject: threadSubject ?? this.threadSubject,
      threadFid: threadFid ?? this.threadFid,
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
      final totalPages = _extractTotalPages(result);
      final subject = _extractSubject(result);
      final fid = _extractFid(result);
      state = AsyncValue.data(PostListState(
        posts: posts,
        currentPage: page,
        totalPages: totalPages,
        threadSubject: subject,
        threadFid: fid,
      ),);
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
    // 每页帖数，API 字段名为 ppp (posts per page)
    final perPage = int.tryParse(variables['ppp']?.toString() ?? '') ?? 30;
    final totalPosts = replies + 1; // 主楼 + 回复
    return (totalPosts / perPage).ceil().clamp(1, 9999);
  }

  String? _extractSubject(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return null;
    final thread = variables['thread'] as Map<String, dynamic>?;
    return thread?['subject']?.toString();
  }

  String? _extractFid(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return null;
    final thread = variables['thread'] as Map<String, dynamic>?;
    return thread?['fid']?.toString();
  }

  Future<void> goToPage(int page) async {
    await _loadPage(page);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull?.currentPage ?? 1;
    await _loadPage(current);
  }
}
