import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/forum_search_query.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';
import 'api_service_provider.dart';

/// Discuz `allowsearch` 常见间隔；客户端提交冷却，降低连点触发限流。
const searchSubmitCooldown = Duration(seconds: 60);

sealed class SearchGoToPageResult {
  const SearchGoToPageResult();
}

final class SearchGoToPageSuccess extends SearchGoToPageResult {
  const SearchGoToPageSuccess();
}

final class SearchGoToPageFailure extends SearchGoToPageResult {
  const SearchGoToPageFailure(
    this.message, {
    this.loginRequired = false,
  });

  final String message;
  final bool loginRequired;
}

class SearchUiState {
  const SearchUiState({
    this.type = SearchType.forum,
    this.query = '',
    this.forumQuery = ForumSearchQuery.empty,
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
  final ForumSearchQuery forumQuery;
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

  bool get hasAdvancedFilters => !forumQuery.isDefault;

  SearchUiState copyWith({
    SearchType? type,
    String? query,
    ForumSearchQuery? forumQuery,
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
      forumQuery: forumQuery ?? this.forumQuery,
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

  void updateForumQuery(ForumSearchQuery query) {
    state = state.copyWith(forumQuery: query);
  }

  void clearAdvancedFilters() {
    state = state.copyWith(
      forumQuery: state.forumQuery.copyWith(
        author: '',
        filter: ForumSearchFilter.all,
        specials: const {},
        srchfromSeconds: 0,
        before: false,
        orderby: 'lastpost',
        ascending: false,
        forumIds: const {},
      ),
      forumHits: const [],
      count: 0,
      currentPage: 1,
      totalPages: 1,
      pageHref: '',
      hasSearched: false,
      clearError: true,
    );
  }

  Future<void> submit(String rawKeyword) async {
    if (state.isLoading) return;
    if (state.isCoolingDown) {
      final sec = state.cooldownRemainingSeconds;
      state = state.copyWith(
        error: '搜索过于频繁，请 $sec 秒后再试',
      );
      return;
    }

    if (state.type == SearchType.user) {
      final query = rawKeyword.trim();
      if (query.isEmpty) {
        state = state.copyWith(error: '请输入搜索关键词', hasSearched: false);
        return;
      }
      await _runSearch(
        query: query,
        forumQuery: null,
        userQuery: query,
      );
      return;
    }

    final forumQuery = state.forumQuery.copyWith(keyword: rawKeyword);
    final validationError = forumQuery.validate();
    if (validationError != null) {
      state = state.copyWith(error: validationError, hasSearched: false);
      return;
    }

    await _runSearch(
      query: forumQuery.trimmedKeyword.isNotEmpty
          ? forumQuery.trimmedKeyword
          : forumQuery.trimmedAuthor,
      forumQuery: forumQuery,
      userQuery: null,
    );
  }

  Future<void> _runSearch({
    required String query,
    required ForumSearchQuery? forumQuery,
    required String? userQuery,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      query: query,
      forumQuery: forumQuery ?? state.forumQuery,
      hasSearched: true,
    );

    try {
      if (state.type == SearchType.forum) {
        final page = await _api.searchForum(query: forumQuery!);
        _applyForumPage(page, query: query, startCooldown: true);
      } else {
        final page = await _api.searchUser(query: userQuery!);
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

  Future<SearchGoToPageResult> goToPage(int page) async {
    if (state.type != SearchType.forum) return const SearchGoToPageSuccess();
    if (page < 1 || page > state.totalPages || page == state.currentPage) {
      return const SearchGoToPageSuccess();
    }
    if (state.isLoading) return const SearchGoToPageSuccess();
    final query = state.query;
    if (query.isEmpty) return const SearchGoToPageSuccess();

    if (page > 1 && state.pageHref.isEmpty) {
      return const SearchGoToPageFailure('无法翻页，请重新搜索');
    }

    final previous = state;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.searchForum(
        query: state.forumQuery,
        page: page,
        pageHref: state.pageHref.isEmpty ? null : state.pageHref,
      );
      if (result.hasError) {
        state = previous.copyWith(isLoading: false);
        return SearchGoToPageFailure(result.error!);
      }
      _applyForumPage(result, query: query, startCooldown: false);
      return const SearchGoToPageSuccess();
    } on LoginRequiredException {
      state = previous.copyWith(isLoading: false);
      return const SearchGoToPageFailure(
        '请先登录后重试',
        loginRequired: true,
      );
    } catch (e, st) {
      state = previous.copyWith(isLoading: false);
      return SearchGoToPageFailure(friendlyError(e, '搜索翻页', st));
    }
  }

  void _applyForumPage(
    ForumSearchPage page, {
    required String query,
    bool startCooldown = true,
  }) {
    if (page.hasError) {
      state = state.copyWith(
        isLoading: false,
        query: query,
        hasSearched: true,
        forumHits: const [],
        userHits: const [],
        count: 0,
        currentPage: 1,
        totalPages: 1,
        pageHref: '',
        error: page.error,
      );
      return;
    }

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
      clearError: true,
    );
    if (startCooldown) _startCooldown();
  }

  void _applyUserPage(UserSearchPage page, {required String query}) {
    if (page.hasError) {
      state = state.copyWith(
        isLoading: false,
        query: query,
        hasSearched: true,
        userHits: const [],
        forumHits: const [],
        count: 0,
        currentPage: 1,
        totalPages: 1,
        pageHref: '',
        error: page.error,
      );
      return;
    }

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
      clearError: true,
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
