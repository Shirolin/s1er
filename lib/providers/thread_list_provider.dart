import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thread.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class ThreadListState {
  final List<Thread> threads;
  final int currentPage;
  final int totalPages;
  final bool isLoading;

  ThreadListState({
    this.threads = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isLoading = true,
  });

  ThreadListState copyWith({
    List<Thread>? threads,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
  }) {
    return ThreadListState(
      threads: threads ?? this.threads,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final threadListProvider = StateNotifierProvider.family<
    ThreadListNotifier, AsyncValue<ThreadListState>, String>(
  (ref, fid) => ThreadListNotifier(
    fid: fid,
    apiService: ApiService(ref.watch(httpClientProvider)),
  ),
);

class ThreadListNotifier extends StateNotifier<AsyncValue<ThreadListState>> {
  final String fid;
  final ApiService _apiService;

  ThreadListNotifier({
    required this.fid,
    required ApiService apiService,
  })  : _apiService = apiService,
        super(const AsyncValue.loading()) {
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.getThreadListRaw(fid, page: page);
      final threads = ApiService.parseThreadList(result);
      final totalPages = _extractTotalPages(result);
      state = AsyncValue.data(ThreadListState(
        threads: threads,
        currentPage: page,
        totalPages: totalPages,
        isLoading: false,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  int _extractTotalPages(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return 1;
    // Discuz! 返回 threads 字段表示帖子总数，perpage 表示每页数量
    final threads = int.tryParse(variables['threads']?.toString() ?? '') ?? 0;
    final perPage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 30;
    if (threads <= 0 || perPage <= 0) return 1;
    return (threads / perPage).ceil();
  }

  Future<void> goToPage(int page) async {
    await _loadPage(page);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull?.currentPage ?? 1;
    await _loadPage(current);
  }
}
