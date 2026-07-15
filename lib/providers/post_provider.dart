import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/open_scroll_target.dart';
import '../models/post.dart';
import '../models/poll.dart';
import '../models/thread_open_intent.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/poll_vote_cache.dart';
import '../services/rate_log_service.dart';
import '../utils/thread_navigation.dart';
import 'api_service_provider.dart';
import 'reading_history_provider.dart';
import 'settings_provider.dart';
import 'thread_open_intent_provider.dart';
import 'thread_rate_logs_provider.dart';

class PostListState {
  PostListState({
    this.posts = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.threadSubject,
    this.threadFid,
    this.threadSpecial = 0,
    this.perPage = S1Constants.postsPerPageFallback,
    this.totalReplies = 0,
    this.poll,
    this.filterAuthorId,
    this.filterAuthorName,
    this.allowReply = true,
    this.openScrollTarget,
    this.locateError,
  });

  final List<Post> posts;
  final int currentPage;
  final int totalPages;
  final String? threadSubject;
  final String? threadFid;
  final int threadSpecial;
  final int perPage;
  final int totalReplies;
  final ThreadPoll? poll;
  final String? filterAuthorId;
  final String? filterAuthorName;
  final bool allowReply;

  /// 首屏一次性滚动落点；Screen 消费后应通过 [clearOpenScrollTarget] 清除。
  final OpenScrollTarget? openScrollTarget;

  /// pid 定位失败时的用户可读说明（加载仍可能落到某一页）。
  final String? locateError;

  bool get isFiltering => filterAuthorId != null;

  PostListState copyWith({
    List<Post>? posts,
    int? currentPage,
    int? totalPages,
    String? threadSubject,
    String? threadFid,
    int? threadSpecial,
    int? perPage,
    int? totalReplies,
    ThreadPoll? poll,
    String? filterAuthorId,
    String? filterAuthorName,
    bool clearFilter = false,
    bool? allowReply,
    OpenScrollTarget? openScrollTarget,
    bool clearOpenScrollTarget = false,
    String? locateError,
    bool clearLocateError = false,
  }) {
    return PostListState(
      posts: posts ?? this.posts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      threadSubject: threadSubject ?? this.threadSubject,
      threadFid: threadFid ?? this.threadFid,
      threadSpecial: threadSpecial ?? this.threadSpecial,
      perPage: perPage ?? this.perPage,
      totalReplies: totalReplies ?? this.totalReplies,
      poll: poll ?? this.poll,
      filterAuthorId:
          clearFilter ? null : (filterAuthorId ?? this.filterAuthorId),
      filterAuthorName:
          clearFilter ? null : (filterAuthorName ?? this.filterAuthorName),
      allowReply: allowReply ?? this.allowReply,
      openScrollTarget: clearOpenScrollTarget
          ? null
          : (openScrollTarget ?? this.openScrollTarget),
      locateError: clearLocateError ? null : (locateError ?? this.locateError),
    );
  }
}

final rateLogServiceProvider = Provider<RateLogService>((ref) {
  return RateLogService(ref.watch(httpClientProvider));
});

final pollVoteCacheProvider =
    Provider.family<PollVoteCache, String>((ref, uid) {
  ref.watch(pollVotesBootstrapProvider);
  return PollVoteCache(ref.watch(localDataProvider), uid);
});

class PostNotifier extends AsyncNotifier<PostListState> {
  PostNotifier(this.tid);

  final String tid;
  String? _filterAuthorId;
  String? _filterAuthorName;

  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  Future<PostListState> build() async {
    final intent = ref.read(threadOpenIntentProvider(tid));
    final mode = intent?.mode ?? ThreadOpenMode.resume;

    if (mode == ThreadOpenMode.post) {
      final pid = intent?.pid;
      if (pid != null && pid.isNotEmpty) {
        return _openByPid(pid);
      }
    }

    if (mode == ThreadOpenMode.page) {
      final page = resolveThreadInitialPage(intent: intent, record: null);
      final loaded = await _loadPage(page);
      return loaded.copyWith(openScrollTarget: const ScrollToPageTop());
    }

    // resume
    final record = ref.read(readingRecordProvider(tid));
    var page = resolveThreadInitialPage(intent: intent, record: record);
    var loaded = await _loadPage(page);

    // B3：在首屏暴露前用 API 总页数再校正
    if (record != null &&
        record.isFinished &&
        record.hasNewPages(loaded.totalPages)) {
      final targetPage = (record.totalPages + 1).clamp(1, loaded.totalPages);
      if (loaded.currentPage < targetPage) {
        loaded = await _loadPage(targetPage);
        return loaded.copyWith(openScrollTarget: const ScrollToPageTop());
      }
    }

    final scrollTarget = resolveResumeScrollTarget(
      record: record,
      loadedPage: loaded.currentPage,
      totalPages: loaded.totalPages,
    );
    return loaded.copyWith(openScrollTarget: scrollTarget);
  }

  Future<PostListState> _openByPid(String pid) async {
    try {
      final page = await _apiService.locatePostPage(tid, pid);
      final loaded = await _loadPage(page);
      final found = loaded.posts.any((p) => p.pid == pid);
      if (!found) {
        return loaded.copyWith(
          openScrollTarget: const ScrollToPageTop(),
          locateError: '未找到目标楼层',
        );
      }
      return loaded.copyWith(
        openScrollTarget: ScrollToPid(pid),
        clearLocateError: true,
      );
    } catch (e) {
      if (!ref.mounted) rethrow;
      final loaded = await _loadPage(1);
      return loaded.copyWith(
        openScrollTarget: const ScrollToPageTop(),
        locateError: '定位楼层失败',
      );
    }
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
    final result = await _apiService.getThreadDetail(
      tid,
      page: page,
      authorId: _filterAuthorId,
    );
    final loaded = _buildStateFromResult(result, page);
    if (!ref.mounted) return loaded;

    unawaited(
      ref.read(threadRateLogsProvider(tid).notifier).ensurePageRateLogs(page),
    );
    return loaded;
  }

  PostListState _buildStateFromResult(Map<String, dynamic> result, int page) {
    final posts = ApiService.parsePostList(result);
    final variables = result['Variables'] as Map<String, dynamic>? ?? {};
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final perPage = int.tryParse(variables['ppp']?.toString() ?? '') ??
        S1Constants.postsPerPageFallback;
    final totalReplies = int.tryParse(thread['replies']?.toString() ?? '') ?? 0;
    final totalPosts = totalReplies + 1;
    final totalPages = (totalPosts / perPage).ceil().clamp(1, 9999);
    final allowReply = thread['allowreply']?.toString() != '0';
    final threadSpecial =
        int.tryParse(thread['special']?.toString() ?? '') ?? 0;

    return PostListState(
      posts: posts,
      currentPage: page,
      totalPages: totalPages,
      threadSubject: thread['subject']?.toString(),
      threadFid: thread['fid']?.toString(),
      threadSpecial: threadSpecial,
      perPage: perPage,
      totalReplies: totalReplies,
      poll: page == 1
          ? _pollWithUserVotes(variables, ApiService.parsePoll(result))
          : null,
      filterAuthorId: _filterAuthorId,
      filterAuthorName: _filterAuthorName,
      allowReply: allowReply,
    );
  }

  Future<void> locatePid(String pid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _openByPid(pid));
  }

  Future<void> goToPage(int page) async {
    final previous = state.asData?.value;
    state = await AsyncValue.guard(() async {
      final loaded = await _loadPage(page);
      return loaded.copyWith(
        openScrollTarget: const ScrollToPageTop(),
        clearLocateError: true,
      );
    });
    if (state.hasError && previous != null) {
      state = AsyncValue.data(previous);
    }
  }

  void clearOpenScrollTarget() {
    final current = state.asData?.value;
    if (current == null || current.openScrollTarget == null) return;
    state = AsyncValue.data(current.copyWith(clearOpenScrollTarget: true));
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
}

final postProvider = AsyncNotifierProvider.autoDispose
    .family<PostNotifier, PostListState, String>(
  PostNotifier.new,
  dependencies: [threadOpenIntentProvider],
);
