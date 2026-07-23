import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/favorite_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';
import 'favorite_forum_pins_provider.dart';

class FavoriteMembershipState {
  const FavoriteMembershipState({
    this.keys = const {},
    this.favids = const {},
    this.isLoading = false,
  });

  final Set<String> keys;
  final Map<String, String> favids;
  final bool isLoading;

  bool isFavorited(FavoriteType type, String id) =>
      keys.contains('${type.name}:$id');

  String? favidFor(FavoriteType type, String id) => favids['${type.name}:$id'];

  FavoriteMembershipState copyWith({
    Set<String>? keys,
    Map<String, String>? favids,
    bool? isLoading,
  }) {
    return FavoriteMembershipState(
      keys: keys ?? this.keys,
      favids: favids ?? this.favids,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoriteMembershipNotifier extends Notifier<FavoriteMembershipState> {
  bool _syncEnsured = false;

  @override
  FavoriteMembershipState build() {
    ref.listen(
      authStateProvider,
      (previous, next) {
        if (!next.isLoggedIn) {
          _syncEnsured = false;
          state = const FavoriteMembershipState();
        }
      },
      fireImmediately: true,
    );
    return const FavoriteMembershipState();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  String? get _uid => ref.read(authStateProvider).user?.uid;

  Future<void> ensureSynced() async {
    if (_syncEnsured || state.isLoading) return;
    if (state.keys.isNotEmpty) {
      _syncEnsured = true;
      return;
    }
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    _syncEnsured = true;
    await sync();
  }

  Future<void> sync() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      state = const FavoriteMembershipState();
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final threadFuture = _apiService.getFavoriteList(
        uid: uid,
        type: 'thread',
        page: 1,
      );
      final forumFuture = fetchAllFavoriteForums(
        api: _apiService,
        uid: uid,
      );
      final results = await Future.wait([threadFuture, forumFuture]);
      final threadResult = results[0] as FavoriteListResult;
      final forumItems = results[1] as List<FavoriteItem>;

      final keys = <String>{};
      final favids = <String, String>{};
      for (final item in [...threadResult.items, ...forumItems]) {
        keys.add(item.membershipKey);
        if (item.favid.isNotEmpty) {
          favids[item.membershipKey] = item.favid;
        }
      }

      state = FavoriteMembershipState(keys: keys, favids: favids);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String?> toggleThread(String tid) async {
    return _toggle(FavoriteType.thread, tid);
  }

  Future<String?> toggleForum(String fid) async {
    return _toggle(FavoriteType.forum, fid);
  }

  Future<String?> _toggle(FavoriteType type, String id) async {
    if (_uid == null || _uid!.isEmpty) {
      return '请先登录';
    }

    final key = '${type.name}:$id';
    final wasFavorited = state.keys.contains(key);

    if (wasFavorited) {
      final favid = state.favids[key];
      if (favid == null || favid.isEmpty) {
        return '无法取消收藏，请刷新收藏列表后重试';
      }
      final result = await _apiService.removeFavorite(favid: favid);
      if (!result.isSuccess) {
        return result.error ?? '取消收藏失败';
      }
      final nextKeys = Set<String>.from(state.keys)..remove(key);
      final nextFavids = Map<String, String>.from(state.favids)..remove(key);
      state = state.copyWith(keys: nextKeys, favids: nextFavids);
      _invalidateFavoriteLists();
      return null;
    }

    final result = await _apiService.addFavorite(type: type, id: id);
    if (!result.isSuccess) {
      return result.error ?? '收藏失败';
    }

    final nextKeys = Set<String>.from(state.keys)..add(key);
    final nextFavids = Map<String, String>.from(state.favids);
    if (result.favid != null && result.favid!.isNotEmpty) {
      nextFavids[key] = result.favid!;
    }
    state = state.copyWith(keys: nextKeys, favids: nextFavids);
    if (result.favid == null || result.favid!.isEmpty) {
      await sync();
    }
    _invalidateFavoriteLists();
    return null;
  }

  void _invalidateFavoriteLists() {
    invalidateFavoriteForumCaches(ref);
  }

  void untrack(FavoriteItem item) {
    final key = item.membershipKey;
    if (!state.keys.contains(key)) return;
    final nextKeys = Set<String>.from(state.keys)..remove(key);
    final nextFavids = Map<String, String>.from(state.favids)..remove(key);
    state = state.copyWith(keys: nextKeys, favids: nextFavids);
  }
}

final favoriteMembershipProvider =
    NotifierProvider<FavoriteMembershipNotifier, FavoriteMembershipState>(
  FavoriteMembershipNotifier.new,
);
