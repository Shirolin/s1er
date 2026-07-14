import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_space_item.dart';
import '../services/api_service.dart';
import '../services/talker.dart';
import 'api_service_provider.dart';

class UserSpaceState {
  UserSpaceState({
    this.threads = const [],
    this.replies = const [],
    this.threadPage = 1,
    this.replyPage = 1,
    this.threadTotalPages = 1,
    this.replyTotalPages = 1,
    this.repliesLoaded = false,
  });

  final List<UserSpaceItem> threads;
  final List<UserSpaceItem> replies;
  final int threadPage;
  final int replyPage;
  final int threadTotalPages;
  final int replyTotalPages;
  final bool repliesLoaded;

  UserSpaceState copyWith({
    List<UserSpaceItem>? threads,
    List<UserSpaceItem>? replies,
    int? threadPage,
    int? replyPage,
    int? threadTotalPages,
    int? replyTotalPages,
    bool? repliesLoaded,
  }) {
    return UserSpaceState(
      threads: threads ?? this.threads,
      replies: replies ?? this.replies,
      threadPage: threadPage ?? this.threadPage,
      replyPage: replyPage ?? this.replyPage,
      threadTotalPages: threadTotalPages ?? this.threadTotalPages,
      replyTotalPages: replyTotalPages ?? this.replyTotalPages,
      repliesLoaded: repliesLoaded ?? this.repliesLoaded,
    );
  }
}

typedef UserSpaceParams = (String uid, bool isSelf);

class UserSpaceNotifier extends AsyncNotifier<UserSpaceState> {
  UserSpaceNotifier(this.params);

  final UserSpaceParams params;

  String get uid => params.$1;
  bool get isSelf => params.$2;

  @override
  Future<UserSpaceState> build() => _loadThreads();

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<UserSpaceState> _loadThreads() async {
    final threads = isSelf
        ? await _apiService.getMySpaceList(type: 'thread', page: 1)
        : await _apiService.getUserSpaceList(uid: uid, type: 'thread', page: 1);

    return UserSpaceState(
      threads: threads.items,
      threadTotalPages: threads.totalPages,
    );
  }

  Future<void> ensureRepliesLoaded() async {
    final current = state.asData?.value;
    if (current == null || current.repliesLoaded) return;

    state = await AsyncValue.guard(() async {
      final replies = await _apiService.getUserSpaceList(
        uid: uid,
        type: 'reply',
        page: 1,
      );
      return current.copyWith(
        replies: replies.items,
        replyTotalPages: replies.totalPages,
        repliesLoaded: true,
      );
    });
    if (state.hasError) {
      final error = state.error;
      final stack = state.stackTrace;
      if (error != null && stack != null) {
        talker.handle(error, stack, 'Load user replies failed');
      }
    }
  }

  Future<void> goToThreadPage(int page) async {
    state = await AsyncValue.guard(() async {
      final result = isSelf
          ? await _apiService.getMySpaceList(type: 'thread', page: page)
          : await _apiService.getUserSpaceList(
              uid: uid,
              type: 'thread',
              page: page,
            );
      final cur = state.asData?.value ?? UserSpaceState();
      return cur.copyWith(
        threads: result.items,
        threadPage: page,
        threadTotalPages: result.totalPages,
      );
    });
  }

  Future<void> goToReplyPage(int page) async {
    await ensureRepliesLoaded();
    state = await AsyncValue.guard(() async {
      final result = await _apiService.getUserSpaceList(
        uid: uid,
        type: 'reply',
        page: page,
      );
      final cur = state.asData?.value ?? UserSpaceState();
      return cur.copyWith(
        replies: result.items,
        replyPage: page,
        replyTotalPages: result.totalPages,
        repliesLoaded: true,
      );
    });
    if (state.hasError) {
      final error = state.error;
      final stack = state.stackTrace;
      if (error != null && stack != null) {
        talker.handle(error, stack, 'Load user reply page failed');
      }
    }
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final threads = isSelf
          ? await _apiService.getMySpaceList(type: 'thread', page: 1)
          : await _apiService.getUserSpaceList(
              uid: uid, type: 'thread', page: 1,);
      var next = UserSpaceState(
        threads: threads.items,
        threadTotalPages: threads.totalPages,
        threadPage: 1,
      );
      if (current?.repliesLoaded ?? false) {
        final replies = await _apiService.getUserSpaceList(
          uid: uid,
          type: 'reply',
          page: current!.replyPage,
        );
        next = next.copyWith(
          replies: replies.items,
          replyPage: current.replyPage,
          replyTotalPages: replies.totalPages,
          repliesLoaded: true,
        );
      }
      return next;
    });
  }
}

final userSpaceProvider = AsyncNotifierProvider.autoDispose
    .family<UserSpaceNotifier, UserSpaceState, UserSpaceParams>(
  UserSpaceNotifier.new,
);
