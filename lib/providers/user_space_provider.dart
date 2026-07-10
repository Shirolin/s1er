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
    _loadThreads();
  }
  final String uid;
  final bool isSelf;
  final ApiService _apiService;

  Future<void> _loadThreads() async {
    try {
      final result = isSelf
          ? await _apiService.getMySpaceList(type: 'thread', page: 1)
          : await _apiService.getUserSpaceList(uid: uid, type: 'thread', page: 1);
      
      // 重要：必须在 await 之后获取最新的 state，防止 loadReplies 的结果被覆盖
      final current = state.valueOrNull ?? UserSpaceState();
      state = AsyncValue.data(current.copyWith(
        threads: result.items,
        threadTotalPages: result.totalPages,
        threadPage: 1,
      ),);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadReplies() async {
    // 如果已经加载过第一页，不再重复加载
    if (state.valueOrNull?.replies.isNotEmpty ?? false) return;
    
    try {
      final result = await _apiService.getUserSpaceList(uid: uid, type: 'reply', page: 1);
      
      // 重要：必须在 await 之后获取最新的 state，防止 _loadThreads 的结果被覆盖
      final current = state.valueOrNull ?? UserSpaceState();
      state = AsyncValue.data(current.copyWith(
        replies: result.items,
        replyTotalPages: result.totalPages,
        replyPage: 1,
      ),);
    } catch (e, st) {
      // 如果 thread 已经加载成功，不要因为回复加载失败就显示全屏错误
      if (state.hasValue) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> goToThreadPage(int page) async {
    try {
      final result = isSelf
          ? await _apiService.getMySpaceList(type: 'thread', page: page)
          : await _apiService.getUserSpaceList(uid: uid, type: 'thread', page: page);
      
      final current = state.valueOrNull ?? UserSpaceState();
      state = AsyncValue.data(current.copyWith(
        threads: result.items,
        threadPage: page,
        threadTotalPages: result.totalPages,
      ),);
    } catch (_) {}
  }

  Future<void> goToReplyPage(int page) async {
    try {
      final result = await _apiService.getUserSpaceList(uid: uid, type: 'reply', page: page);
      
      final current = state.valueOrNull ?? UserSpaceState();
      state = AsyncValue.data(current.copyWith(
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
