import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice_item.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';

class NoticeListState {
  NoticeListState({
    this.items = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.feed = NoticeFeed.mypost,
  });

  final List<NoticeItem> items;
  final int currentPage;
  final int totalPages;
  final NoticeFeed feed;

  NoticeListState copyWith({
    List<NoticeItem>? items,
    int? currentPage,
    int? totalPages,
    NoticeFeed? feed,
  }) {
    return NoticeListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      feed: feed ?? this.feed,
    );
  }
}

class NoticeListNotifier extends AsyncNotifier<NoticeListState> {
  NoticeListNotifier({this.seed});

  final NoticeListState? seed;
  final Map<NoticeFeed, NoticeListState> _cache = {};

  @override
  Future<NoticeListState> build() async {
    if (seed != null) {
      _cache[seed!.feed] = seed!;
      return seed!;
    }
    return _loadPage(NoticeFeed.mypost, 1);
  }

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<NoticeListState> _loadPage(NoticeFeed feed, int page) async {
    final result = await _apiService.getNoticeList(feed: feed, page: page);
    final next = NoticeListState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
      feed: feed,
    );
    _cache[feed] = next;
    return next;
  }

  Future<void> selectFeed(NoticeFeed feed) async {
    if (state.asData?.value.feed == feed) return;
    final cached = _cache[feed];
    if (cached != null) {
      state = AsyncValue.data(cached);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(feed, 1));
  }

  Future<void> goToPage(int page) async {
    final current = state.asData?.value;
    final feed = current?.feed ?? NoticeFeed.mypost;
    state = await AsyncValue.guard(() => _loadPage(feed, page));
    if (state.hasError && current != null) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> refresh() async {
    final currentPage = state.asData?.value.currentPage ?? 1;
    final feed = state.asData?.value.feed ?? NoticeFeed.mypost;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(feed, currentPage));
  }
}

final noticeListProvider =
    AsyncNotifierProvider.autoDispose<NoticeListNotifier, NoticeListState>(
  NoticeListNotifier.new,
);
