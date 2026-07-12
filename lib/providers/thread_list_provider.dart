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

class ThreadListNotifier extends AsyncNotifier<ThreadListState> {
  ThreadListNotifier(this.fid);

  final String fid;

  @override
  Future<ThreadListState> build() => _loadPage(1);

  ApiService get _apiService => ApiService(ref.watch(httpClientProvider));

  Future<ThreadListState> _loadPage(int page) async {
    final result = await _apiService.getThreadListRaw(fid, page: page);
    final threads = ApiService.parseThreadList(result);
    final totalPages = _extractTotalPages(result);
    return ThreadListState(
      threads: threads,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  int _extractTotalPages(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return 1;

    final forum = variables['forum'] as Map<String, dynamic>?;
    int? totalThreads;
    if (forum != null) {
      totalThreads = int.tryParse(forum['threads']?.toString() ?? '');
    }
    totalThreads ??= int.tryParse(
      (variables['threadcount'] ?? variables['threads'])?.toString() ?? '',
    );
    if (totalThreads == null || totalThreads <= 0) return 1;

    final perPage = int.tryParse(variables['tpp']?.toString() ?? '') ?? 30;
    if (perPage <= 0) return 1;
    return (totalThreads / perPage).ceil();
  }

  Future<void> goToPage(int page) async {
    final current = state.asData?.value;
    state = await AsyncValue.guard(() => _loadPage(page));
    if (state.hasError && current != null) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(1));
  }
}

final threadListProvider = AsyncNotifierProvider.autoDispose
    .family<ThreadListNotifier, ThreadListState, String>(
  ThreadListNotifier.new,
);
