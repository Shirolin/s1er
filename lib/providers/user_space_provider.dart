import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_space_item.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/talker.dart';

class UserSpaceState {
  UserSpaceState({
    this.threads = const [],
    this.replies = const [],
    this.threadPage = 1,
    this.replyPage = 1,
    this.threadTotalPages = 1,
    this.replyTotalPages = 1,
  });
  final List<UserSpaceItem> threads;
  final List<UserSpaceItem> replies;
  final int threadPage;
  final int replyPage;
  final int threadTotalPages;
  final int replyTotalPages;

  UserSpaceState copyWith({
    List<UserSpaceItem>? threads,
    List<UserSpaceItem>? replies,
    int? threadPage,
    int? replyPage,
    int? threadTotalPages,
    int? replyTotalPages,
  }) {
    return UserSpaceState(
      threads: threads ?? this.threads,
      replies: replies ?? this.replies,
      threadPage: threadPage ?? this.threadPage,
      replyPage: replyPage ?? this.replyPage,
      threadTotalPages: threadTotalPages ?? this.threadTotalPages,
      replyTotalPages: replyTotalPages ?? this.replyTotalPages,
    );
  }
}

final userSpaceProvider = StateNotifierProvider.autoDispose.family<
    UserSpaceNotifier, AsyncValue<UserSpaceState>, (String, bool)>(
  (ref, params) => UserSpaceNotifier(
    uid: params.$1,
    apiService: ApiService(ref.watch(httpClientProvider)),
    isSelf: params.$2,
  ),
);

class UserSpaceNotifier extends StateNotifier<AsyncValue<UserSpaceState>> {
  UserSpaceNotifier({
    required this.uid,
    required ApiService apiService,
    required this.isSelf,
  })  : _apiService = apiService,
        super(const AsyncValue.loading()) {
    _loadAll();
  }
  final String uid;
  final bool isSelf;
  final ApiService _apiService;

  Future<void> _loadAll() async {
    try {
      final threadFuture = isSelf
          ? _apiService.getMySpaceList(type: 'thread', page: 1)
          : _apiService.getUserSpaceList(uid: uid, type: 'thread', page: 1);
      final replyFuture = _apiService.getUserSpaceList(uid: uid, type: 'reply', page: 1);

      final results = await Future.wait<UserSpaceListResult>([
        threadFuture,
        replyFuture,
      ]);
      final threads = results[0];
      final replies = results[1];

      state = AsyncValue.data(
        UserSpaceState(
          threads: threads.items,
          threadTotalPages: threads.totalPages,
          replies: replies.items,
          replyTotalPages: replies.totalPages,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> goToThreadPage(int page) async {
    try {
      final result = isSelf
          ? await _apiService.getMySpaceList(type: 'thread', page: page)
          : await _apiService.getUserSpaceList(uid: uid, type: 'thread', page: page);
      final cur = state.valueOrNull ?? UserSpaceState();
      state = AsyncValue.data(
        cur.copyWith(
          threads: result.items,
          threadPage: page,
          threadTotalPages: result.totalPages,
        ),
      );
    } catch (e, st) {
      talker.handle(e, st, 'Load user thread page failed');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> goToReplyPage(int page) async {
    try {
      final result = await _apiService.getUserSpaceList(uid: uid, type: 'reply', page: page);
      final cur = state.valueOrNull ?? UserSpaceState();
      state = AsyncValue.data(
        cur.copyWith(
          replies: result.items,
          replyPage: page,
          replyTotalPages: result.totalPages,
        ),
      );
    } catch (e, st) {
      talker.handle(e, st, 'Load user reply page failed');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadAll();
  }
}
