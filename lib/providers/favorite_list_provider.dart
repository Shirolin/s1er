import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/favorite_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';

enum FavoriteSegment { all, thread, forum }

extension FavoriteSegmentX on FavoriteSegment {
  String? get apiType {
    switch (this) {
      case FavoriteSegment.all:
        return null;
      case FavoriteSegment.thread:
        return 'thread';
      case FavoriteSegment.forum:
        return 'forum';
    }
  }
}

class FavoriteListState {
  FavoriteListState({
    this.items = const [],
    this.currentPage = 1,
    this.totalPages = 1,
  });

  final List<FavoriteItem> items;
  final int currentPage;
  final int totalPages;

  FavoriteListState copyWith({
    List<FavoriteItem>? items,
    int? currentPage,
    int? totalPages,
  }) {
    return FavoriteListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

class FavoriteListNotifier extends AsyncNotifier<FavoriteListState> {
  FavoriteListNotifier(this.segment);

  final FavoriteSegment segment;

  @override
  Future<FavoriteListState> build() async {
    return _loadPage(1);
  }

  ApiService get _apiService => ref.watch(apiServiceProvider);

  String? get _uid {
    final user = ref.read(authStateProvider).user;
    return user?.uid;
  }

  Future<FavoriteListState> _loadPage(int page) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw LoginRequiredException();
    }

    final result = await _apiService.getFavoriteList(
      uid: uid,
      type: segment.apiType,
      page: page,
    );
    return FavoriteListState(
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

  Future<bool> removeItem(FavoriteItem item) async {
    if (item.favid.isEmpty) return false;

    final current = state.asData?.value;
    if (current == null) return false;

    final optimistic =
        current.items.where((e) => e.favid != item.favid).toList();
    state = AsyncValue.data(current.copyWith(items: optimistic));

    final result = await _apiService.removeFavorite(favid: item.favid);
    if (!result.isSuccess) {
      state = AsyncValue.data(current);
      return false;
    }
    return true;
  }
}

final favoriteListProvider = AsyncNotifierProvider.autoDispose
    .family<FavoriteListNotifier, FavoriteListState, FavoriteSegment>(
  FavoriteListNotifier.new,
);
