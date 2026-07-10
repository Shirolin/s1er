import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../config/constants.dart';
import '../models/post.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/poll_vote_cache.dart';
class PostListState {

  PostListState({
    this.posts = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.threadSubject,
    this.threadFid,
    this.perPage = S1Constants.postsPerPageFallback,
    this.totalReplies = 0,
    this.poll,
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

  /// 投票帖数据（仅 `thread.special == 1` 时有值）
  final ThreadPoll? poll;

  PostListState copyWith({
    List<Post>? posts,
    int? currentPage,
    int? totalPages,
    String? threadSubject,
    String? threadFid,
    int? perPage,
    int? totalReplies,
    ThreadPoll? poll,
  }) {
    return PostListState(
      posts: posts ?? this.posts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      threadSubject: threadSubject ?? this.threadSubject,
      threadFid: threadFid ?? this.threadFid,
      perPage: perPage ?? this.perPage,
      totalReplies: totalReplies ?? this.totalReplies,
      poll: poll ?? this.poll,
    );
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(httpClientProvider));
});

final pollVoteCacheProvider = Provider.family<PollVoteCache, String>((ref, uid) {
  return PollVoteCache(Hive.box('cache'), uid);
});

final postProvider = StateNotifierProvider.autoDispose.family<
    PostNotifier, AsyncValue<PostListState>, String>(
  (ref, tid) => PostNotifier(
    tid: tid,
    apiService: ref.watch(apiServiceProvider),
    ref: ref,
  ),
);

class PostNotifier extends StateNotifier<AsyncValue<PostListState>> {

  PostNotifier({
    required this.tid,
    required ApiService apiService,
    required Ref ref,
  })  : _apiService = apiService,
        _ref = ref,
        super(const AsyncValue.loading()) {
    _loadPage(1);
  }
  final String tid;
  final ApiService _apiService;
  final Ref _ref;

  ThreadPoll? _pollWithUserVotes(
    Map<String, dynamic> variables,
    ThreadPoll? poll,
  ) {
    if (poll == null) return null;
    final uid = variables['member_uid']?.toString() ?? '';
    if (uid.isEmpty || uid == '0') return poll;
    final votes = _ref.read(pollVoteCacheProvider(uid)).getVotes(tid);
    return votes.isEmpty ? poll : poll.withUserVotes(votes);
  }

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
        poll: page == 1
            ? _pollWithUserVotes(variables, ApiService.parsePoll(result))
            : null,
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
