import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dark_room_entry.dart';
import '../services/forum_tools_service.dart';
import '../services/talker.dart';
import 'forum_tools_provider.dart';

class DarkRoomState {
  const DarkRoomState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<DarkRoomEntry> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  DarkRoomState copyWith({
    List<DarkRoomEntry>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
    bool clearCursor = false,
  }) {
    return DarkRoomState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class DarkRoomNotifier extends AsyncNotifier<DarkRoomState> {
  @override
  Future<DarkRoomState> build() => _loadFirstPage();

  ForumToolsService get _service => ref.read(forumToolsServiceProvider);

  Future<DarkRoomState> _loadFirstPage() async {
    final page = await _service.getDarkRoom();
    return DarkRoomState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadFirstPage);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final cursor = current.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await _service.getDarkRoom(cursor: cursor);
      final merged = [...current.items, ...page.items];
      state = AsyncValue.data(
        DarkRoomState(
          items: merged,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      talker.handle(e, st, 'Load more dark room failed');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final darkRoomProvider =
    AsyncNotifierProvider.autoDispose<DarkRoomNotifier, DarkRoomState>(
  DarkRoomNotifier.new,
);
