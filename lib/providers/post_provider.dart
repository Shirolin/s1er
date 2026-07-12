import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/post.dart';
import '../models/poll.dart';
import '../models/rate_log.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/poll_vote_cache.dart';
import '../services/rate_log_service.dart';
import 'settings_provider.dart';
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
    this.filterAuthorId,
    this.filterAuthorName,
    this.rateLogs = const {},
    this.allowReply = true,
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

  /// 当前激活的作者筛选 ID（服务端过滤），null 表示不过滤
  final String? filterAuthorId;

  /// 当前筛选的作者名（用于 UI 提示）
  final String? filterAuthorName;

  /// 评分记录（key = pid）
  final Map<String, PostRateLog> rateLogs;

  /// 是否允许回复（来自 API `thread.allowreply`）
  final bool allowReply;

  /// 是否正在按作者筛选
  bool get isFiltering => filterAuthorId != null;

  PostListState copyWith({
    List<Post>? posts,
    int? currentPage,
    int? totalPages,
    String? threadSubject,
    String? threadFid,
    int? perPage,
    int? totalReplies,
    ThreadPoll? poll,
    String? filterAuthorId,
    String? filterAuthorName,
    bool clearFilter = false,
    Map<String, PostRateLog>? rateLogs,
    bool? allowReply,
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
      filterAuthorId: clearFilter ? null : (filterAuthorId ?? this.filterAuthorId),
      filterAuthorName: clearFilter ? null : (filterAuthorName ?? this.filterAuthorName),
      rateLogs: rateLogs ?? this.rateLogs,
      allowReply: allowReply ?? this.allowReply,
    );
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(httpClientProvider));
});

final rateLogServiceProvider = Provider<RateLogService>((ref) {
  return RateLogService(ref.watch(httpClientProvider));
});

final pollVoteCacheProvider = Provider.family<PollVoteCache, String>((ref, uid) {
  return PollVoteCache(ref.watch(localDataProvider), uid);
});

final postProvider = StateNotifierProvider.autoDispose.family<
    PostNotifier, AsyncValue<PostListState>, String>(
  (ref, tid) => PostNotifier(
    tid: tid,
    apiService: ref.watch(apiServiceProvider),
    rateLogService: ref.watch(rateLogServiceProvider),
    ref: ref,
  ),
);

class PostNotifier extends StateNotifier<AsyncValue<PostListState>> {

  PostNotifier({
    required this.tid,
    required ApiService apiService,
    required RateLogService rateLogService,
    required Ref ref,
  })  : _apiService = apiService,
        _rateLogService = rateLogService,
        _ref = ref,
        super(const AsyncValue.loading()) {
    _loadPage(1, showFullLoading: true);
  }
  final String tid;
  final ApiService _apiService;
  final RateLogService _rateLogService;
  final Ref _ref;

  /// 服务端按作者筛选：null 表示不过滤
  String? _filterAuthorId;
  String? _filterAuthorName;

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

  Future<void> _loadPage(int page, {bool showFullLoading = false}) async {
    final previous = state.valueOrNull;
    if (showFullLoading) {
      state = const AsyncValue.loading();
    }
    try {
      final detailFuture = _apiService.getThreadDetail(
        tid,
        page: page,
        authorId: _filterAuthorId,
      );
      final rateLogFuture = _rateLogService.fetchRateLogs(tid, page: page);

      final results = await Future.wait<Object>([detailFuture, rateLogFuture]);
      final result = results[0] as Map<String, dynamic>;
      final rateLogs = results[1] as Map<String, PostRateLog>;

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
      final allowReply = thread['allowreply']?.toString() != '0';

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
        filterAuthorId: _filterAuthorId,
        filterAuthorName: _filterAuthorName,
        rateLogs: rateLogs,
        allowReply: allowReply,
      ),);
    } catch (e, st) {
      if (showFullLoading || previous == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// 定位特定回复，自动跳转到对应页。
  Future<void> locatePid(String pid) async {
    state = const AsyncValue.loading();
    final page = await _apiService.locatePostPage(tid, pid);
    await _loadPage(page, showFullLoading: true);
  }

  Future<void> goToPage(int page) async {
    await _loadPage(page);
  }

  /// 按指定作者筛选帖子（服务端过滤，翻页保持生效）
  void filterByAuthor(String authorId, String authorName) {
    _filterAuthorId = authorId;
    _filterAuthorName = authorName;
    _loadPage(1);
  }

  /// 取消作者筛选
  void clearFilter() {
    _filterAuthorId = null;
    _filterAuthorName = null;
    _loadPage(1);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull?.currentPage ?? 1;
    await _loadPage(current, showFullLoading: true);
  }

  /// 异步加载特定帖子的完整评分记录
  Future<void> loadFullRateLog(String pid) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final fullRateLog = await _rateLogService.fetchFullRateLog(tid, pid);
    if (fullRateLog != null) {
      final newRateLogs = Map<String, PostRateLog>.from(currentState.rateLogs);
      newRateLogs[pid] = fullRateLog;
      state = AsyncValue.data(currentState.copyWith(rateLogs: newRateLogs));
    }
  }
}
