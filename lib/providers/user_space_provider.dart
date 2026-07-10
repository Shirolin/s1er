import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_space_item.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

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
    UserSpaceNotifier, AsyncValue<UserSpaceState>, String>(
  (ref, uid) => UserSpaceNotifier(
    uid: uid,
    apiService: ApiService(ref.watch(httpClientProvider)),
  ),
);

class UserSpaceNotifier extends StateNotifier<AsyncValue<UserSpaceState>> {

  UserSpaceNotifier({
    required this.uid,
    required ApiService apiService,
  })  : _apiService = apiService,
        super(const AsyncValue.loading()) {
    _loadThreads();
  }
  final String uid;
  final ApiService _apiService;

  Future<void> _loadThreads() async {
    try {
      final result = await _apiService.getMySpaceList(type: 'thread', page: 1);
      state = AsyncValue.data(UserSpaceState(
        threads: result.items,
        threadTotalPages: result.totalPages,
      ),);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadReplies() async {
    final current = state.valueOrNull;
    if (current != null && current.replies.isNotEmpty) return;
    try {
      final result = await _apiService.getUserSpaceList(uid: uid, type: 'reply');
      state = AsyncValue.data(current!.copyWith(
        replies: result.items,
        replyTotalPages: result.totalPages,
      ),);
    } catch (e, st) {
      if (current != null) {
        state = AsyncValue.data(current);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> goToThreadPage(int page) async {
    final current = state.valueOrNull;
    try {
      final result = await _apiService.getMySpaceList(type: 'thread', page: page);
      state = AsyncValue.data((current ?? UserSpaceState()).copyWith(
        threads: result.items,
        threadPage: page,
        threadTotalPages: result.totalPages,
      ),);
    } catch (_) {}
  }

  Future<void> goToReplyPage(int page) async {
    final current = state.valueOrNull;
    try {
      final result = await _apiService.getUserSpaceList(uid: uid, type: 'reply', page: page);
      state = AsyncValue.data((current ?? UserSpaceState()).copyWith(
        replies: result.items,
        replyPage: page,
        replyTotalPages: result.totalPages,
      ),);
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadThreads();
  }
}
