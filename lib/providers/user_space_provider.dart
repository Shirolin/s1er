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

typedef UserSpaceParams = (String uid, bool isSelf);

class UserSpaceNotifier extends AsyncNotifier<UserSpaceState> {
  UserSpaceNotifier(this.params);

  final UserSpaceParams params;

  String get uid => params.$1;
  bool get isSelf => params.$2;

  @override
  Future<UserSpaceState> build() => _loadAll();

  ApiService get _apiService => ApiService(ref.watch(httpClientProvider));

  Future<UserSpaceState> _loadAll() async {
    final threadFuture = isSelf
        ? _apiService.getMySpaceList(type: 'thread', page: 1)
        : _apiService.getUserSpaceList(uid: uid, type: 'thread', page: 1);
    final replyFuture =
        _apiService.getUserSpaceList(uid: uid, type: 'reply', page: 1);

    final results = await Future.wait<UserSpaceListResult>([
      threadFuture,
      replyFuture,
    ]);
    final threads = results[0];
    final replies = results[1];

    return UserSpaceState(
      threads: threads.items,
      threadTotalPages: threads.totalPages,
      replies: replies.items,
      replyTotalPages: replies.totalPages,
    );
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadAll);
  }
}

final userSpaceProvider = AsyncNotifierProvider.autoDispose
    .family<UserSpaceNotifier, UserSpaceState, UserSpaceParams>(
  UserSpaceNotifier.new,
);
