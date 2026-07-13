import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/private_message_item.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';

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

class PmListNotifier extends AsyncNotifier<PmListState> {
  PmListNotifier({this.seed});

  final PmListState? seed;

  @override
  Future<PmListState> build() async {
    if (seed != null) return seed!;
    return _loadPage(1);
  }

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<PmListState> _loadPage(int page) async {
    final result = await _apiService.getPmList(page: page);
    return PmListState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
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
