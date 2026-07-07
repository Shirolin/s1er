import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thread.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class ThreadListState {

  ThreadListState({
    this.threads = const [],
    this.currentPage = 1,
    this.totalPages = 1,
  });
  final List<Thread> threads;
  final int currentPage;
  final int totalPages;

  ThreadListState copyWith({
    List<Thread>? threads,
    int? currentPage,
    int? totalPages,
  }) {
    return ThreadListState(
      threads: threads ?? this.threads,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
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

  ThreadListNotifier({
    required this.fid,
    required ApiService apiService,
  })  : _apiService = apiService,
        super(const AsyncValue.loading()) {
    _initLoad();
  }
  final String fid;
  final ApiService _apiService;

  Future<void> _initLoad() async {
    try {
      final result = await _apiService.getThreadListRaw(fid, page: 1);
      final threads = ApiService.parseThreadList(result);
      final totalPages = _extractTotalPages(result);
      state = AsyncValue.data(ThreadListState(
        threads: threads,
        currentPage: 1,
        totalPages: totalPages,
      ),);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  int _extractTotalPages(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return 1;
    final threads = int.tryParse(variables['threads']?.toString() ?? '') ?? 0;
    final perPage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 30;
    if (threads <= 0 || perPage <= 0) return 1;
    return (threads / perPage).ceil();
  }

  Future<void> goToPage(int page) async {
    try {
      final result = await _apiService.getThreadListRaw(fid, page: page);
      final threads = ApiService.parseThreadList(result);
      final totalPages = _extractTotalPages(result);
      state = AsyncValue.data(ThreadListState(
        threads: threads,
        currentPage: page,
        totalPages: totalPages,
      ),);
    } catch (_) {
      // 翻页失败时保留当前数据，不做全屏错误展示
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _initLoad();
  }
}
