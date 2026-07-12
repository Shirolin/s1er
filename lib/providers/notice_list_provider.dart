import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice_item.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class NoticeListState {
  NoticeListState({
    this.items = const [],
    this.currentPage = 1,
    this.totalPages = 1,
  });

  final List<NoticeItem> items;
  final int currentPage;
  final int totalPages;

  NoticeListState copyWith({
    List<NoticeItem>? items,
    int? currentPage,
    int? totalPages,
  }) {
    return NoticeListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

class NoticeListNotifier extends AsyncNotifier<NoticeListState> {
  NoticeListNotifier({this.seed});

  final NoticeListState? seed;

  @override
  Future<NoticeListState> build() async {
    if (seed != null) return seed!;
    return _loadPage(1);
  }

  ApiService get _apiService => ApiService(ref.watch(httpClientProvider));

  Future<NoticeListState> _loadPage(int page) async {
    final result = await _apiService.getNoticeList(page: page);
    return NoticeListState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
    );
  }

  Future<void> goToPage(int page) async {
    final current = state.asData?.value;
    state = await AsyncValue.guard(() => _loadPage(page));
    if (state.hasError && current != null) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> refresh() async {
    final currentPage = state.asData?.value.currentPage ?? 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(currentPage));
  }
}

final noticeListProvider =
    AsyncNotifierProvider.autoDispose<NoticeListNotifier, NoticeListState>(
  NoticeListNotifier.new,
);
