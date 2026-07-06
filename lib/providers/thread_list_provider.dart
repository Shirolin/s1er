import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thread.dart';
import '../services/api_service.dart';
import '../services/html_parser_service.dart';
import 'auth_provider.dart';

final threadListProvider = StateNotifierProvider.family<
    ThreadListNotifier, AsyncValue<List<Thread>>, String>(
  (ref, fid) => ThreadListNotifier(
    fid: fid,
    apiService: ApiService(ref.watch(httpClientProvider)),
    htmlParser: HtmlParserService(ref.watch(httpClientProvider)),
  ),
);

class ThreadListNotifier extends StateNotifier<AsyncValue<List<Thread>>> {
  final String fid;
  final ApiService _apiService;
  final HtmlParserService _htmlParser;
  int _currentPage = 1;

  ThreadListNotifier({
    required this.fid,
    required ApiService apiService,
    required HtmlParserService htmlParser,
  })  : _apiService = apiService,
        _htmlParser = htmlParser,
        super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      var threads = await _apiService.getThreadList(fid);
      if (threads.isEmpty) {
        threads = await _htmlParser.getThreadList(fid);
      }
      state = AsyncValue.data(threads);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    _currentPage++;
    try {
      final newThreads =
          await _apiService.getThreadList(fid, page: _currentPage);
      state.whenData((threads) {
        state = AsyncValue.data([...threads, ...newThreads]);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    _currentPage = 1;
    await loadInitial();
  }
}
