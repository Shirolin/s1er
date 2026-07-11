import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_list_result.dart';
import '../models/private_message_item.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class PmListState {
  PmListState({
    this.items = const [],
    this.currentPage = 1,
    this.totalPages = 1,
  });

  final List<PrivateMessageItem> items;
  final int currentPage;
  final int totalPages;

  PmListState copyWith({
    List<PrivateMessageItem>? items,
    int? currentPage,
    int? totalPages,
  }) {
    return PmListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

final pmListProvider = StateNotifierProvider.autoDispose<
    PmListNotifier, AsyncValue<PmListState>>(
  (ref) => PmListNotifier(
    apiService: ApiService(ref.watch(httpClientProvider)),
  ),
);

class PmListNotifier extends StateNotifier<AsyncValue<PmListState>> {
  PmListNotifier({
    required ApiService apiService,
    AsyncValue<PmListState>? initialState,
  })  : _apiService = apiService,
        super(initialState ?? const AsyncValue.loading()) {
    if (initialState == null) {
      _initLoad();
    }
  }

  final ApiService _apiService;

  Future<void> _initLoad() async {
    try {
      final result = await _apiService.getPmList(page: 1);
      state = AsyncValue.data(_toState(result));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  PmListState _toState(PmListResult result) {
    return PmListState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _initLoad();
  }
}
