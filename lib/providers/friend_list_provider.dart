import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_exceptions.dart';
import '../models/friend_summary.dart';
import 'auth_provider.dart';
import 'forum_tools_provider.dart';

class FriendListNotifier extends AsyncNotifier<FriendListResult> {
  @override
  Future<FriendListResult> build() => _load();

  Future<FriendListResult> _load() async {
    final uid = ref.read(authStateProvider).user?.uid;
    if (uid == null || uid.isEmpty) {
      throw LoginRequiredException();
    }
    return ref.read(forumToolsServiceProvider).getFriendList(uid: uid);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

final friendListProvider =
    AsyncNotifierProvider.autoDispose<FriendListNotifier, FriendListResult>(
      FriendListNotifier.new,
    );
