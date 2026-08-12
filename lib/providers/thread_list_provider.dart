import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blacklist_record.dart';
import '../models/thread.dart';
import '../models/thread_list_query.dart';
import 'api_service_provider.dart';
import 'blacklist_provider.dart';
import 'pinned_threads_provider.dart';
import 'settings_provider.dart';
import '../services/api_service.dart';

class ThreadListState {
  ThreadListState({
    this.threads = const [],
    this.sourceThreads = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.forumName,
    this.threadTypes = const {},
    this.selectedTypeId,
    this.query = ThreadListQuery.defaults,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Thread> threads;
  final List<Thread> sourceThreads;
  final int currentPage;
  final int totalPages;
  final String? forumName;
  final Map<String, String> threadTypes;
  final String? selectedTypeId;
  final ThreadListQuery query;
  final bool isLoading;
  final String? errorMessage;

  ThreadListState copyWith({
    List<Thread>? threads,
    List<Thread>? sourceThreads,
    int? currentPage,
    int? totalPages,
    String? forumName,
    Map<String, String>? threadTypes,
    String? selectedTypeId,
    bool clearSelectedType = false,
    ThreadListQuery? query,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ThreadListState(
      threads: threads ?? this.threads,
      sourceThreads: sourceThreads ?? this.sourceThreads,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      forumName: forumName ?? this.forumName,
      threadTypes: threadTypes ?? this.threadTypes,
      selectedTypeId:
          clearSelectedType ? null : (selectedTypeId ?? this.selectedTypeId),
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ThreadListNotifier extends AsyncNotifier<ThreadListState> {
  ThreadListNotifier(this.fid);

  final String fid;
  String? _selectedTypeId;
  ThreadListQuery _query = ThreadListQuery.defaults;
  Map<String, String> _threadTypes = const {};

  @override
  Future<ThreadListState> build() {
    ref.listen(blacklistProvider, (_, __) => _refilterCurrentPage());
    ref.listen(
      settingsProvider.select((s) => s.hideStickyEffectiveFor(fid)),
      (_, __) => _refilterCurrentPage(),
    );
    return _loadPage(1);
  }

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<ThreadListState> _loadPage(int page) async {
    final result = await _apiService.getThreadListRaw(
      fid,
      page: page,
      typeId: _selectedTypeId,
      query: _query,
    );
    final threads = ApiService.parseThreadList(result);
    final parsedTypes = ApiService.parseThreadTypes(result);
    if (parsedTypes.isNotEmpty) _threadTypes = parsedTypes;
    final filtered = _filterThreads(threads);
    final totalPages = ApiService.parseThreadListTotalPages(
      result,
      currentPage: page,
      itemCount: threads.length,
      isFiltered: _selectedTypeId != null || !_query.isDefault,
    );
    _mergePinnedReplyCounts(threads);
    return ThreadListState(
      threads: filtered,
      sourceThreads: threads,
      currentPage: page,
      totalPages: totalPages,
      forumName: ApiService.parseForumDisplayName(result),
      threadTypes: _threadTypes,
      selectedTypeId: _selectedTypeId,
      query: _query,
    );
  }

  void _mergePinnedReplyCounts(List<Thread> threads) {
    if (!ref.mounted || threads.isEmpty) return;
    final pinned = ref.read(pinnedThreadsProvider);
    if (pinned.isEmpty) return;
    final pinnedTids = {for (final p in pinned) p.tid};
    final updates = <String, int>{};
    for (final thread in threads) {
      if (!pinnedTids.contains(thread.tid)) continue;
      updates[thread.tid] = thread.replies;
    }
    if (updates.isEmpty) return;
    ref.read(pinnedThreadsProvider.notifier).mergeReplyCounts(updates);
  }

  List<Thread> _filterThreads(List<Thread> threads) {
    final hideSticky = ref.read(settingsProvider).hideStickyEffectiveFor(fid);
    return threads.where((t) {
      if (hideSticky && t.isSticky) return false;
      return t.authorId.isEmpty ||
          !ref
              .read(blacklistServiceProvider)
              .hasScope(t.authorId, BlacklistRecord.scopeThread);
    }).toList();
  }

  void _refilterCurrentPage() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(threads: _filterThreads(current.sourceThreads)),
    );
  }

  Future<void> goToPage(int page) async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(isLoading: true, clearError: true),
      );
    }
    try {
      state = AsyncValue.data(await _loadPage(page));
    } catch (error) {
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(isLoading: false, errorMessage: error.toString()),
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> selectType(String? typeId) async {
    final normalized = typeId == null || typeId.isEmpty ? null : typeId;
    if (_selectedTypeId == normalized) return;
    final previousType = _selectedTypeId;
    final current = state.asData?.value;
    _selectedTypeId = normalized;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          selectedTypeId: normalized,
          clearSelectedType: normalized == null,
          isLoading: true,
          clearError: true,
        ),
      );
    }
    try {
      state = AsyncValue.data(await _loadPage(1));
    } catch (error) {
      _selectedTypeId = previousType;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(isLoading: false, errorMessage: error.toString()),
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> setQuery(ThreadListQuery query) async {
    if (_query == query) return;
    final previousQuery = _query;
    final current = state.asData?.value;
    _query = query;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          query: query,
          isLoading: true,
          clearError: true,
        ),
      );
    }
    try {
      state = AsyncValue.data(await _loadPage(1));
    } catch (error) {
      _query = previousQuery;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(isLoading: false, errorMessage: error.toString()),
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    final page = current?.currentPage ?? 1;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(isLoading: true, clearError: true),
      );
    } else {
      state = const AsyncValue.loading();
    }
    try {
      state = AsyncValue.data(await _loadPage(page));
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(isLoading: false, errorMessage: error.toString()),
        );
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
}

final threadListProvider = AsyncNotifierProvider.autoDispose
    .family<ThreadListNotifier, ThreadListState, String>(
  ThreadListNotifier.new,
);
