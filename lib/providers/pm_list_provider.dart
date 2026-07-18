import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blacklist_record.dart';
import '../models/private_message_item.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';
import 'blacklist_provider.dart';

class PmListState {
  PmListState({
    this.items = const [],
    this.sourceItems = const [],
    this.currentPage = 1,
    this.totalPages = 1,
  });

  final List<PrivateMessageItem> items;
  final List<PrivateMessageItem> sourceItems;
  final int currentPage;
  final int totalPages;

  PmListState copyWith({
    List<PrivateMessageItem>? items,
    List<PrivateMessageItem>? sourceItems,
    int? currentPage,
    int? totalPages,
  }) {
    return PmListState(
      items: items ?? this.items,
      sourceItems: sourceItems ?? this.sourceItems,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

class PmListNotifier extends AsyncNotifier<PmListState> {
  PmListNotifier({this.seed});

  final PmListState? seed;

  @override
  Future<PmListState> build() async {
    ref.listen(blacklistProvider, (_, __) => _refilterCurrentPage());
    if (seed != null) return seed!;
    return _loadPage(1);
  }

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<PmListState> _loadPage(int page) async {
    final result = await _apiService.getPmList(page: page);
    return PmListState(
      items: _filterItems(result.items),
      sourceItems: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
    );
  }

  List<PrivateMessageItem> _filterItems(List<PrivateMessageItem> items) {
    final blacklist = ref.read(blacklistServiceProvider);
    return items
        .where(
          (item) => !blacklist.hasScope(item.touid, BlacklistRecord.scopePm),
        )
        .toList();
  }

  void _refilterCurrentPage() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(items: _filterItems(current.sourceItems)),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(1));
  }
}

final pmListProvider =
    AsyncNotifierProvider.autoDispose<PmListNotifier, PmListState>(
  PmListNotifier.new,
);
