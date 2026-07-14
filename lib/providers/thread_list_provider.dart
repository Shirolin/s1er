import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blacklist_record.dart';
import '../models/thread.dart';
import 'api_service_provider.dart';
import 'blacklist_provider.dart';
import '../services/api_service.dart';

class ThreadListState {
  ThreadListState({
    this.threads = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.forumName,
    this.threadTypes = const {},
    this.selectedTypeId,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Thread> threads;
  final int currentPage;
  final int totalPages;
  final String? forumName;
  final Map<String, String> threadTypes;
  final String? selectedTypeId;
  final bool isLoading;
  final String? errorMessage;

  ThreadListState copyWith({
    List<Thread>? threads,
    int? currentPage,
    int? totalPages,
    String? forumName,
    Map<String, String>? threadTypes,
    String? selectedTypeId,
    bool clearSelectedType = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ThreadListState(
      threads: threads ?? this.threads,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      forumName: forumName ?? this.forumName,
      threadTypes: threadTypes ?? this.threadTypes,
      selectedTypeId:
          clearSelectedType ? null : (selectedTypeId ?? this.selectedTypeId),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ThreadListNotifier extends AsyncNotifier<ThreadListState> {
  ThreadListNotifier(this.fid);

  final String fid;
  String? _selectedTypeId;
  Map<String, String> _threadTypes = const {};

  @override
  Future<ThreadListState> build() {
    // 黑名单变更时重新过滤当前页。
    ref.watch(blacklistProvider);
    return _loadPage(1);
  }

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<ThreadListState> _loadPage(int page) async {
    final result = await _apiService.getThreadListRaw(
      fid,
      page: page,
      typeId: _selectedTypeId,
    );
    final threads = ApiService.parseThreadList(result);
    final parsedTypes = ApiService.parseThreadTypes(result);
    if (parsedTypes.isNotEmpty) _threadTypes = parsedTypes;
    final filtered = threads
        .where(
          (t) =>
              t.authorId.isEmpty ||
              !ref
                  .read(blacklistServiceProvider)
                  .hasScope(t.authorId, BlacklistRecord.scopeThread),
        )
        .toList();
    final totalPages = ApiService.parseThreadListTotalPages(
      result,
      currentPage: page,
      itemCount: threads.length,
      isFiltered: _selectedTypeId != null,
    );
    return ThreadListState(
      threads: filtered,
      currentPage: page,
      totalPages: totalPages,
      forumName: ApiService.parseForumDisplayName(result),
      threadTypes: _threadTypes,
      selectedTypeId: _selectedTypeId,
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
        ThreadListState(
          threads: current.threads,
          currentPage: current.currentPage,
          totalPages: current.totalPages,
          forumName: current.forumName,
          threadTypes: current.threadTypes,
          selectedTypeId: normalized,
          isLoading: true,
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
