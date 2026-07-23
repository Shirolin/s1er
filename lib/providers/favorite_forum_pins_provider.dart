import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';
import 'favorite_list_provider.dart';

/// Max pages when pulling all favorited forums for the home pin section.
const int kFavoriteForumPinsMaxPages = 20;

/// Loads every favorited forum (paginated), newest [dateline] first.
class FavoriteForumPinsNotifier extends AsyncNotifier<List<FavoriteItem>> {
  @override
  Future<List<FavoriteItem>> build() async {
    ref.listen(
      authStateProvider.select((auth) => auth.user?.uid),
      (previous, next) {
        if (previous != next) {
          ref.invalidateSelf();
        }
      },
    );

    final uid = ref.read(authStateProvider).user?.uid;
    if (uid == null || uid.isEmpty) {
      return const [];
    }

    final api = ref.watch(apiServiceProvider);
    return fetchAllFavoriteForums(api: api, uid: uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).user?.uid;
      if (uid == null || uid.isEmpty) return const <FavoriteItem>[];
      return fetchAllFavoriteForums(
        api: ref.read(apiServiceProvider),
        uid: uid,
      );
    });
  }
}

final favoriteForumPinsProvider =
    AsyncNotifierProvider<FavoriteForumPinsNotifier, List<FavoriteItem>>(
  FavoriteForumPinsNotifier.new,
);

/// Fetches all forum favorites up to [kFavoriteForumPinsMaxPages].
Future<List<FavoriteItem>> fetchAllFavoriteForums({
  required ApiService api,
  required String uid,
  int maxPages = kFavoriteForumPinsMaxPages,
}) async {
  final items = <FavoriteItem>[];
  var page = 1;
  var totalPages = 1;

  while (page <= totalPages && page <= maxPages) {
    final result = await api.getFavoriteList(
      uid: uid,
      type: 'forum',
      page: page,
    );
    items.addAll(result.items);
    totalPages = result.totalPages < 1 ? 1 : result.totalPages;
    if (result.items.isEmpty) break;
    page += 1;
  }

  items.sort((a, b) => b.dateline.compareTo(a.dateline));
  return items;
}

/// Invalidates pin + paged favorite list providers after membership changes.
void invalidateFavoriteForumCaches(Ref ref) {
  ref.invalidate(favoriteForumPinsProvider);
  ref.invalidate(favoriteListProvider(FavoriteSegment.all));
  ref.invalidate(favoriteListProvider(FavoriteSegment.thread));
  ref.invalidate(favoriteListProvider(FavoriteSegment.forum));
}
