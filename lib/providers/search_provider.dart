import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_result.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';
import 'api_service_provider.dart';

/// Discuz `allowsearch` 常见间隔；客户端提交冷却，降低连点触发限流。
const searchSubmitCooldown = Duration(seconds: 30);

class SearchUiState {
  const SearchUiState({
    this.type = SearchType.forum,
    this.query = '',
    this.forumHits = const [],
    this.userHits = const [],
    this.count = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.pageHref = '',
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
    this.cooldownRemainingSeconds = 0,
  });

  final SearchType type;
  final String query;
  final List<ForumSearchHit> forumHits;
  final List<UserSearchHit> userHits;
  final int count;
  final int currentPage;
  final int totalPages;
  final String pageHref;
  final bool isLoading;
  final bool hasSearched;
  final Object? error;
  final int cooldownRemainingSeconds;

  bool get isCoolingDown => cooldownRemainingSeconds > 0;

  SearchUiState copyWith({
    SearchType? type,
    String? query,
    List<ForumSearchHit>? forumHits,
    List<UserSearchHit>? userHits,
    int? count,
    int? currentPage,
    int? totalPages,
    String? pageHref,
    bool? isLoading,
    bool? hasSearched,
    Object? error,
    bool clearError = false,
    int? cooldownRemainingSeconds,
    bool clearCooldown = false,
  }) {
    return SearchUiState(
      type: type ?? this.type,
      query: query ?? this.query,
      forumHits: forumHits ?? this.forumHits,
      userHits: userHits ?? this.userHits,
      count: count ?? this.count,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      pageHref: pageHref ?? this.pageHref,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: clearError ? null : (error ?? this.error),
      cooldownRemainingSeconds: clearCooldown
          ? 0
          : (cooldownRemainingSeconds ?? this.cooldownRemainingSeconds),
    );
  }
}

class SearchNotifier extends Notifier<SearchUiState> {
  Timer? _cooldownTimer;

  @override
  SearchUiState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return const SearchUiState();
  }

  ApiService get _api => ref.read(apiServiceProvider);

  void setType(SearchType type) {
    if (type == state.type) return;
    state = SearchUiState(
      type: type,
      cooldownRemainingSeconds: state.cooldownRemainingSeconds,
    );
  }

  Future<void> submit(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      state = state.copyWith(error: '请输入搜索关键词', hasSearched: false);
      return;
    }
    if (state.isLoading) return;
    if (state.isCoolingDown) {
      final sec = state.cooldownRemainingSeconds;
      state = state.copyWith(
        error: '搜索过于频繁，请 $sec 秒后再试',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      query: query,
      hasSearched: true,
    );

    try {
      if (state.type == SearchType.forum) {
        final page = await _api.searchForum(query: query);
        _applyForumPage(page, query: query);
      } else {
        final page = await _api.searchUser(query: query);
        _applyUserPage(page, query: query);
      }
    } on LoginRequiredException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
        forumHits: const [],
        userHits: const [],
      );
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: friendlyError(e, '搜索', st),
        forumHits: const [],
        userHits: const [],
      );
    }
  }

  Future<void> goToPage(int page) async {
    if (state.type != SearchType.forum) return;
    if (page < 1 || page > state.totalPages || page == state.currentPage) {
      return;
    }
    if (state.isLoading) return;
    final query = state.query;
    if (query.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.searchForum(
        query: query,
        page: page,
        pageHref: state.pageHref.isEmpty ? null : state.pageHref,
      );
      _applyForumPage(result, query: query, startCooldown: false);
    } on LoginRequiredException catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: friendlyError(e, '搜索翻页', st),
      );
    }
  }

  void _applyForumPage(
    ForumSearchPage page, {
    required String query,
    bool startCooldown = true,
  }) {
    state = state.copyWith(
      isLoading: false,
      query: query,
      hasSearched: true,
      forumHits: page.hits,
      userHits: const [],
      count: page.count,
      currentPage: page.currentPage,
      totalPages: page.totalPages < 1 ? 1 : page.totalPages,
      pageHref: page.pageHref,
      error: page.error,
      clearError: !page.hasError,
    );
    if (startCooldown) _startCooldown();
  }

  void _applyUserPage(UserSearchPage page, {required String query}) {
    state = state.copyWith(
      isLoading: false,
      query: query,
      hasSearched: true,
      userHits: page.hits,
      forumHits: const [],
      count: page.hits.length,
      currentPage: 1,
      totalPages: 1,
      pageHref: '',
      error: page.error,
      clearError: !page.hasError,
    );
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    state = state.copyWith(
      cooldownRemainingSeconds: searchSubmitCooldown.inSeconds,
    );
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.cooldownRemainingSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(clearCooldown: true);
        return;
      }
      state = state.copyWith(cooldownRemainingSeconds: remaining);
    });
  }
}

final searchProvider =
    NotifierProvider.autoDispose<SearchNotifier, SearchUiState>(
  SearchNotifier.new,
);
