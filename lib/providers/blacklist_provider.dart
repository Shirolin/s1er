import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blacklist_record.dart';
import '../services/blacklist_service.dart';
import 'settings_provider.dart';

/// 确保黑名单表已加载到内存镜像。
final blacklistBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(localDataProvider).ensureBlacklistLoaded();
});

final blacklistServiceProvider = Provider<BlacklistService>((ref) {
  ref.watch(blacklistBootstrapProvider);
  return BlacklistService(ref.watch(localDataProvider));
});

class BlacklistNotifier extends Notifier<List<BlacklistRecord>> {
  @override
  List<BlacklistRecord> build() {
    return ref.watch(blacklistServiceProvider).getAll();
  }

  void refresh() {
    state = ref.read(blacklistServiceProvider).getAll();
  }

  BlacklistRecord? upsert({
    required String uid,
    String username = '',
    String reason = '',
    List<String> scope = BlacklistRecord.defaultScopes,
  }) {
    final entry = ref.read(blacklistServiceProvider).upsert(
          uid: uid,
          username: username,
          reason: reason,
          scope: scope,
        );
    refresh();
    return entry;
  }

  void remove(String uid) {
    ref.read(blacklistServiceProvider).remove(uid);
    refresh();
  }

  Future<void> clearAll() async {
    await ref.read(blacklistServiceProvider).clearAll();
    refresh();
  }

  bool isBlocked(String uid) =>
      ref.read(blacklistServiceProvider).isBlocked(uid);

  bool hasScope(String uid, String scope) =>
      ref.read(blacklistServiceProvider).hasScope(uid, scope);
}

final blacklistProvider =
    NotifierProvider<BlacklistNotifier, List<BlacklistRecord>>(
  BlacklistNotifier.new,
);

/// uid → scopes 索引，供 O(1) 作用域查询。
final blacklistScopeIndexProvider = Provider<Map<String, Set<String>>>((ref) {
  final list = ref.watch(blacklistProvider);
  return {
    for (final entry in list) entry.uid: entry.scope.toSet(),
  };
});

/// 某用户是否在指定作用域下被屏蔽（随 blacklistProvider 更新）。
final blacklistHasScopeProvider = Provider.autoDispose
    .family<bool, ({String uid, String scope})>((ref, args) {
  return ref.watch(
    blacklistScopeIndexProvider.select(
      (index) => index[args.uid]?.contains(args.scope) ?? false,
    ),
  );
});
