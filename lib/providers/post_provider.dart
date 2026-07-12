import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/post.dart';
import '../models/poll.dart';
import '../models/rate_log.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/poll_vote_cache.dart';
import '../services/rate_log_service.dart';
import '../utils/thread_navigation.dart';
import 'reading_history_provider.dart';
import 'settings_provider.dart';
import 'thread_open_intent_provider.dart';

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
  final int perPage;
  final int totalReplies;
  final ThreadPoll? poll;
  final String? filterAuthorId;
  final String? filterAuthorName;
  final Map<String, PostRateLog> rateLogs;
  final bool allowReply;

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
      filterAuthorId:
          clearFilter ? null : (filterAuthorId ?? this.filterAuthorId),
      filterAuthorName:
          clearFilter ? null : (filterAuthorName ?? this.filterAuthorName),
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

class PostNotifier extends AsyncNotifier<PostListState> {
  PostNotifier(this.tid);

  final String tid;
  String? _filterAuthorId;
  String? _filterAuthorName;

  ApiService get _apiService => ref.read(apiServiceProvider);
  RateLogService get _rateLogService => ref.read(rateLogServiceProvider);

  @override
  Future<PostListState> build() async {
    final intent = ref.read(threadOpenIntentProvider(tid));

    if (intent?.targetPid != null && intent!.targetPid!.isNotEmpty) {
      final page = await _apiService.locatePostPage(tid, intent.targetPid!);
      return _loadPage(page);
    }

    final explicitPage = intent?.initialPage;
    if (explicitPage != null && explicitPage > 1) {
      return _loadPage(explicitPage);
    }

    final record = ref.read(readingRecordProvider(tid));
    final page = resolveThreadInitialPage(intent: intent, record: record);
    return _loadPage(page);
  }

  ThreadPoll? _pollWithUserVotes(
    Map<String, dynamic> variables,
    ThreadPoll? poll,
  ) {
    if (poll == null) return null;
    final uid = variables['member_uid']?.toString() ?? '';
    if (uid.isEmpty || uid == '0') return poll;
    final votes = ref.read(pollVoteCacheProvider(uid)).getVotes(tid);
    return votes.isEmpty ? poll : poll.withUserVotes(votes);
  }

  Future<PostListState> _loadPage(int page) async {
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
    final variables = result['Variables'] as Map<String, dynamic>? ?? {};
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final perPage = int.tryParse(variables['ppp']?.toString() ?? '') ??
        S1Constants.postsPerPageFallback;
    final totalReplies = int.tryParse(thread['replies']?.toString() ?? '') ?? 0;
    final totalPosts = totalReplies + 1;
    final totalPages = (totalPosts / perPage).ceil().clamp(1, 9999);
    final allowReply = thread['allowreply']?.toString() != '0';

    return PostListState(
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
    );
  }

  Future<void> locatePid(String pid) async {
    state = const AsyncValue.loading();
    final page = await _apiService.locatePostPage(tid, pid);
    state = await AsyncValue.guard(() => _loadPage(page));
  }

  Future<void> goToPage(int page) async {
    final previous = state.asData?.value;
    state = await AsyncValue.guard(() => _loadPage(page));
    if (state.hasError && previous != null) {
      state = AsyncValue.data(previous);
    }
  }

  Future<void> filterByAuthor(String authorId, String authorName) async {
    _filterAuthorId = authorId;
    _filterAuthorName = authorName;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(1));
  }

  Future<void> clearFilter() async {
    _filterAuthorId = null;
    _filterAuthorName = null;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(1));
  }

  Future<void> refresh() async {
    final current = state.asData?.value.currentPage ?? 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(current));
  }

  Future<void> loadFullRateLog(String pid) async {
    final currentState = state.asData?.value;
    if (currentState == null) return;

    final fullRateLog = await _rateLogService.fetchFullRateLog(tid, pid);
    if (fullRateLog != null) {
      final newRateLogs = Map<String, PostRateLog>.from(currentState.rateLogs);
      newRateLogs[pid] = fullRateLog;
      state = AsyncValue.data(currentState.copyWith(rateLogs: newRateLogs));
    }
  }
}

final postProvider = AsyncNotifierProvider.autoDispose
    .family<PostNotifier, PostListState, String>(
  PostNotifier.new,
);
