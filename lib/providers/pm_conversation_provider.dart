import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blacklist_record.dart';
import '../models/private_message.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';
import 'blacklist_provider.dart';

class PmConversationState {
  const PmConversationState({
    this.items = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isBlocked = false,
  });

  final List<PrivateMessage> items;
  final int currentPage;
  final int totalPages;
  final bool isBlocked;
}

class PmConversationNotifier extends AsyncNotifier<PmConversationState> {
  PmConversationNotifier(this.touid);

  final String touid;

  @override
  Future<PmConversationState> build() {
    final blocked = ref.watch(
      blacklistHasScopeProvider(
        (uid: touid, scope: BlacklistRecord.scopePm),
      ),
    );
    if (blocked) {
      return Future.value(const PmConversationState(isBlocked: true));
    }
    return _loadPage(1);
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  Future<PmConversationState> _loadPage(int page) async {
    final result = await _apiService.getPmConversation(touid, page: page);
    return PmConversationState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
    );
  }

  Future<void> goToPage(int page) async {
    final previous = state.asData?.value;
    state = await AsyncValue.guard(() => _loadPage(page));
    if (state.hasError && previous != null) {
      state = AsyncValue.data(previous);
    }
  }

  Future<void> refresh() async {
    final page = state.asData?.value.currentPage ?? 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(page));
  }
}

final pmConversationProvider = AsyncNotifierProvider.autoDispose
    .family<PmConversationNotifier, PmConversationState, String>(
  PmConversationNotifier.new,
);
