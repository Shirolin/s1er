import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_space_item.dart';
import '../services/api_service.dart';
import '../services/talker.dart';
import 'api_service_provider.dart';

class UserSpaceListState {
  const UserSpaceListState({
    this.items = const [],
    this.page = 1,
    this.totalPages = 1,
  });

  final List<UserSpaceItem> items;
  final int page;
  final int totalPages;

  UserSpaceListState copyWith({
    List<UserSpaceItem>? items,
    int? page,
    int? totalPages,
  }) {
    return UserSpaceListState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

typedef UserSpaceParams = (String uid, bool isSelf);

abstract class UserSpaceListNotifier extends AsyncNotifier<UserSpaceListState> {
  UserSpaceListNotifier(this.params);

  final UserSpaceParams params;

  String get uid => params.$1;
  bool get isSelf => params.$2;
  String get listType;
  String get _loadErrorLabel;

  ApiService get _apiService => ref.watch(apiServiceProvider);

  Future<UserSpaceListResult> fetchPage(int page);

  @override
  Future<UserSpaceListState> build() => _load(1);

  Future<UserSpaceListState> _load(int page) async {
    final result = await fetchPage(page);
    return UserSpaceListState(
      items: result.items,
      page: page,
      totalPages: result.totalPages,
    );
  }

  Future<void> goToPage(int page) async {
    state = await AsyncValue.guard(() => _load(page));
    if (state.hasError) {
      final error = state.error;
      final stack = state.stackTrace;
      if (error != null && stack != null) {
        talker.handle(error, stack, _loadErrorLabel);
      }
    }
  }

  Future<void> refresh() async {
    final page = state.asData?.value.page ?? 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(page));
    if (state.hasError) {
      final error = state.error;
      final stack = state.stackTrace;
      if (error != null && stack != null) {
        talker.handle(error, stack, _loadErrorLabel);
      }
    }
  }
}

class UserSpaceThreadsNotifier extends UserSpaceListNotifier {
  UserSpaceThreadsNotifier(super.params);

  @override
  String get listType => 'thread';

  @override
  String get _loadErrorLabel => 'Load user threads failed';

  @override
  Future<UserSpaceListResult> fetchPage(int page) {
    if (isSelf) {
      return _apiService.getMySpaceList(type: listType, page: page);
    }
    return _apiService.getUserSpaceList(
      uid: uid,
      type: listType,
      page: page,
    );
  }
}

class UserSpaceRepliesNotifier extends UserSpaceListNotifier {
  UserSpaceRepliesNotifier(super.params);

  @override
  String get listType => 'reply';

  @override
  String get _loadErrorLabel => 'Load user replies failed';

  @override
  Future<UserSpaceListResult> fetchPage(int page) {
    return _apiService.getUserSpaceList(
      uid: uid,
      type: listType,
      page: page,
    );
  }
}

final userSpaceThreadsProvider = AsyncNotifierProvider.autoDispose
    .family<UserSpaceThreadsNotifier, UserSpaceListState, UserSpaceParams>(
  UserSpaceThreadsNotifier.new,
);

final userSpaceRepliesProvider = AsyncNotifierProvider.autoDispose
    .family<UserSpaceRepliesNotifier, UserSpaceListState, UserSpaceParams>(
  UserSpaceRepliesNotifier.new,
);
