import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_list_result.dart';
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

final noticeListProvider = StateNotifierProvider.autoDispose<
    NoticeListNotifier, AsyncValue<NoticeListState>>(
  (ref) => NoticeListNotifier(
    apiService: ApiService(ref.watch(httpClientProvider)),
  ),
);

class NoticeListNotifier extends StateNotifier<AsyncValue<NoticeListState>> {
  NoticeListNotifier({
    required ApiService apiService,
    AsyncValue<NoticeListState>? initialState,
  })  : _apiService = apiService,
        super(initialState ?? const AsyncValue.loading()) {
    if (initialState == null) {
      _initLoad();
    }
  }

  final ApiService _apiService;

  Future<void> _initLoad() async {
    try {
      final result = await _apiService.getNoticeList(page: 1);
      state = AsyncValue.data(_toState(result));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  NoticeListState _toState(NoticeListResult result) {
    return NoticeListState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
    );
  }

  Future<void> goToPage(int page) async {
    final current = state.valueOrNull;
    try {
      final result = await _apiService.getNoticeList(page: page);
      state = AsyncValue.data(_toState(result));
    } catch (_) {
      if (current != null) {
        state = AsyncValue.data(current);
      }
    }
  }

  Future<void> refresh() async {
    final currentPage = state.valueOrNull?.currentPage ?? 1;
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.getNoticeList(page: currentPage);
      state = AsyncValue.data(_toState(result));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
