import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/open_scroll_target.dart';
import '../models/post.dart';
import '../models/poll.dart';
import '../models/thread_open_intent.dart';
import '../services/api_service.dart';
import '../services/discuz_parser.dart';
import '../services/poll_vote_cache.dart';
import '../services/talker.dart';
import '../utils/thread_navigation.dart';
import 'api_service_provider.dart';
import 'pinned_threads_provider.dart';
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

final pollVoteCacheProvider =
    Provider.autoDispose.family<PollVoteCache, String>((ref, uid) {
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
    // 与读帖同生命周期挂住评分 provider；select 常量避免 merge 触发本 Notifier 重建。
    ref.watch(threadRateLogsProvider(tid).select((_) => null));

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

    // B3：列表未提供 live 回复数、且 API 发现更多未读时再校正一页。
    if (record != null &&
        record.isFinished &&
        record.hasNewReplies(loaded.totalReplies)) {
      final targetPage = record.resolveOpenPage(
        loaded.totalReplies,
        perPage: loaded.perPage,
      );
      final listLive = intent?.liveTotalReplies;
      final needsCorrection = loaded.currentPage != targetPage &&
          (listLive == null || listLive < loaded.totalReplies);
      if (needsCorrection) {
        loaded = await _loadPage(targetPage);
      }
    }

    final scrollTarget = resolveResumeScrollTarget(
      record: record,
      loadedPage: loaded.currentPage,
      liveTotalReplies: loaded.totalReplies,
      perPage: loaded.perPage,
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
    } catch (e, st) {
      if (!ref.mounted) rethrow;
      talker.handle(e, st, 'locatePid failed tid=$tid pid=$pid');
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
    final posts = await ApiService.parsePostListAsync(result);
    if (!ref.mounted) {
      return _buildStateFromResult(result, page, posts: posts);
    }
    final loaded = _buildStateFromResult(result, page, posts: posts);
    _syncSeenRepliesAfterLoad(loaded);

    // postlist 不含楼层 rate；v4 的 Variables.commentcount 键即本页有评分
    // 的 pid（v1 无此字段）。只登记标记，实际拉取由可见楼层的评分区按需
    // 触发，避免为每页额外拉整页 HTML，也避免整页批量请求。
    final markedPids = DiscuzParser.parseRateMarkedPids(result);
    // v4 503 降级到 v1 时没有 commentcount，且补发 v4 同样 503（登录态
    // 已知故障）。此时退回整页 HTML 兜底，避免该页所有评分卡消失。
    if (markedPids.isNotEmpty) {
      if (ref.mounted) {
        ref.read(threadRateLogsProvider(tid).notifier).markPids(markedPids);
      }
    } else if (_isLegacyVersion(result)) {
      // 不能 await：整页 HTML 走全局限速队列，会拖住读帖本身。
      unawaited(_loadRateLogsByPageFallback(page));
    }
    return loaded;
  }

  /// v1 降级页的评分兜底：拉一次整页 HTML 解析 `#ratelog_*`。
  ///
  /// 代价约 40 KB，只在正常页永不触发的异常路径使用；失败静默，
  /// 评分属增强功能，不中断读帖。
  Future<void> _loadRateLogsByPageFallback(int page) async {
    try {
      final logs = await ref.read(rateLogServiceProvider).fetchRateLogsByPage(
            tid,
            page: page,
          );
      if (!ref.mounted || logs.isEmpty) return;
      final notifier = ref.read(threadRateLogsProvider(tid).notifier);
      notifier.markPids(logs.keys);
      for (final log in logs.values) {
        notifier.primeRateLog(log.pid, log);
      }
    } catch (e, st) {
      talker.handle(e, st, 'rate log page fallback failed tid=$tid page=$page');
    }
  }

  /// 该响应是否为 v4 不可用后的 v1 降级结果。
  static bool _isLegacyVersion(Map<String, dynamic> result) {
    return result['Version']?.toString() == ApiService.legacyApiVersion;
  }

  /// 是否允许回复。
  ///
  /// `closed` 是两版 API 都稳定给出的开关（1 = 已关闭），优先按它否决；
  /// `allowreply` 在 v4 / v1 下都常为空，有值时再补一刀。两者都缺失时
  /// 保持可回复，与历史行为一致。
  static bool _resolveAllowReply(Map<String, dynamic> thread) {
    if (thread['closed']?.toString() == '1') return false;
    final allowReply = thread['allowreply']?.toString().trim() ?? '';
    if (allowReply.isEmpty) return true;
    return allowReply != '0';
  }

  /// 打开置顶帖时对齐 live / lastSeen（不碰阅读记录）。
  void _syncSeenRepliesAfterLoad(PostListState loaded) {
    if (!ref.mounted) return;
    final notifier = ref.read(pinnedThreadsProvider.notifier);
    if (!notifier.isPinned(tid)) return;
    notifier.markOpened(tid, loaded.totalReplies);
  }

  PostListState _buildStateFromResult(
    Map<String, dynamic> result,
    int page, {
    List<Post>? posts,
  }) {
    final parsedPosts = posts ?? DiscuzParser.parsePostList(result);
    final variables = result['Variables'] as Map<String, dynamic>? ?? {};
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final perPage = int.tryParse(variables['ppp']?.toString() ?? '') ??
        S1Constants.postsPerPageFallback;
    final totalReplies = int.tryParse(thread['replies']?.toString() ?? '') ?? 0;
    final totalPosts = totalReplies + 1;
    final totalPages = (totalPosts / perPage).ceil().clamp(1, 9999);
    final allowReply = _resolveAllowReply(thread);
    final threadSpecial =
        int.tryParse(thread['special']?.toString() ?? '') ?? 0;

    return PostListState(
      posts: parsedPosts,
      currentPage: page,
      totalPages: totalPages,
      threadSubject: thread['subject']?.toString(),
      threadFid: thread['fid']?.toString(),
      threadSpecial: threadSpecial,
      perPage: perPage,
      totalReplies: totalReplies,
      poll: page == 1
          ? _pollWithUserVotes(variables, DiscuzParser.parsePoll(result))
          : null,
      filterAuthorId: _filterAuthorId,
      filterAuthorName: _filterAuthorName,
      allowReply: allowReply,
    );
  }

  Future<void> locatePid(String pid) async {
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<PostListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _openByPid(pid));
  }

  /// 引用跳转返回：恢复到指定页并滚到绝对楼层（同页不重载）。
  ///
  /// 成功返回 `true`；跨页加载失败并回滚后返回 `false`（此时 `hasError` 已清除）。
  Future<bool> restoreToFloor({
    required int page,
    required int absoluteFloor,
  }) async {
    final previous = state.asData?.value;
    if (previous != null && previous.currentPage == page) {
      state = AsyncValue.data(
        previous.copyWith(
          openScrollTarget: ScrollToFloor(absoluteFloor),
          clearLocateError: true,
        ),
      );
      return true;
    }
    state = await AsyncValue.guard(() async {
      final loaded = await _loadPage(page);
      return loaded.copyWith(
        openScrollTarget: ScrollToFloor(absoluteFloor),
        clearLocateError: true,
      );
    });
    if (state.hasError) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
      return false;
    }
    return true;
  }

  /// 翻到指定页。
  ///
  /// 失败时回退到原页并返回 `false`：调用方必须据此中止后续动作（改路由、
  /// 写页码），否则会出现「页码变了、内容还是上一页」且没有任何提示。
  Future<bool> goToPage(int page) async {
    final previous = state.asData?.value;
    state = await AsyncValue.guard(() async {
      final loaded = await _loadPage(page);
      return loaded.copyWith(
        openScrollTarget: const ScrollToPageTop(),
        clearLocateError: true,
      );
    });
    if (!state.hasError) return true;
    if (previous != null) {
      state = AsyncValue.data(previous);
    }
    return false;
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
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<PostListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _loadPage(current));
  }

  /// 异步抓取整帖所有页面的帖子列表（供跨页引用搜索使用，不更改当前 UI 显示状态）
  Future<List<Post>> fetchAllPagesPosts() async {
    final currentState = state.value;
    if (currentState == null) return const [];
    final totalPages = currentState.totalPages;
    final allPosts = <Post>[...currentState.posts];

    // 最多搜索前 10 页避免极长主题风控
    final maxSearchPages = totalPages > 10 ? 10 : totalPages;

    for (var p = 1; p <= maxSearchPages; p++) {
      if (p == currentState.currentPage) continue;
      try {
        final pageState = await _loadPage(p);
        allPosts.addAll(pageState.posts);
      } catch (e, st) {
        talker.warning('Failed to load page $p for quote search', e, st);
      }
    }
    return allPosts;
  }
}

final postProvider = AsyncNotifierProvider.autoDispose
    .family<PostNotifier, PostListState, String>(
  PostNotifier.new,
  dependencies: [threadOpenIntentProvider],
);
