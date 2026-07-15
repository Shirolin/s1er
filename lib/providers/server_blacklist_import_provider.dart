import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_exceptions.dart';
import '../models/blacklist_record.dart';
import '../models/server_blacklist.dart';
import 'auth_provider.dart';
import 'blacklist_provider.dart';
import 'forum_tools_provider.dart';
import 'settings_provider.dart';

class BlacklistImportPreview {
  const BlacklistImportPreview({
    required this.users,
    required this.added,
    required this.updated,
    required this.unchanged,
  });

  final List<ServerBlacklistUser> users;
  final List<ServerBlacklistUser> added;
  final List<ServerBlacklistUser> updated;
  final List<ServerBlacklistUser> unchanged;

  bool get hasChanges => added.isNotEmpty || updated.isNotEmpty;
}

class BlacklistImportResult {
  const BlacklistImportResult({required this.added, required this.updated});

  final int added;
  final int updated;
}

class ServerBlacklistImportNotifier
    extends AsyncNotifier<BlacklistImportPreview?> {
  @override
  BlacklistImportPreview? build() => null;

  Future<BlacklistImportPreview> loadPreview() async {
    _ensureNotLoading();
    state = const AsyncValue.loading();
    try {
      final preview = await _fetchPreview();
      state = AsyncValue.data(preview);
      return preview;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<BlacklistImportResult> apply(BlacklistImportPreview preview) async {
    _ensureNotLoading();
    state = const AsyncValue.loading();
    try {
      var added = 0;
      var updated = 0;
      final local = ref.read(blacklistServiceProvider);
      for (final user in preview.users) {
        final existing = local.get(user.uid);
        if (existing == null) {
          local.upsert(
            uid: user.uid,
            username: user.username,
            scope: BlacklistRecord.defaultScopes,
          );
          added++;
          continue;
        }
        final mergedScopes = BlacklistRecord.normalizeScopes([
          ...existing.scope,
          ...BlacklistRecord.defaultScopes,
        ]);
        final name =
            user.username.isNotEmpty ? user.username : existing.username;
        if (name != existing.username ||
            mergedScopes.length != existing.scope.length) {
          local.upsert(
            uid: user.uid,
            username: name,
            reason: existing.reason,
            scope: mergedScopes,
            createdAt: existing.createdAt,
          );
          updated++;
        }
      }
      await ref.read(localDataProvider).flushPendingWrites();
      ref.read(blacklistProvider.notifier).refresh();
      state = AsyncValue.data(preview);
      return BlacklistImportResult(added: added, updated: updated);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  void _ensureNotLoading() {
    if (state.isLoading) throw StateError('网页黑名单导入正在进行');
  }

  Future<BlacklistImportPreview> _fetchPreview() async {
    final uid = ref.read(authStateProvider).user?.uid;
    if (uid == null || uid.isEmpty) throw LoginRequiredException();
    final service = ref.read(forumToolsServiceProvider);
    final users = <String, ServerBlacklistUser>{};
    var page = 1;
    while (true) {
      final result = await service.getServerBlacklistPage(uid: uid, page: page);
      for (final user in result.items) {
        users[user.uid] = user;
      }
      if (page >= result.totalPages) break;
      page++;
    }
    final local = ref.read(blacklistServiceProvider);
    final added = <ServerBlacklistUser>[];
    final updated = <ServerBlacklistUser>[];
    final unchanged = <ServerBlacklistUser>[];
    for (final user in users.values) {
      final existing = local.get(user.uid);
      if (existing == null) {
        added.add(user);
        continue;
      }
      final mergedScopes = BlacklistRecord.normalizeScopes([
        ...existing.scope,
        ...BlacklistRecord.defaultScopes,
      ]);
      final nameChanged =
          user.username.isNotEmpty && user.username != existing.username;
      if (nameChanged || mergedScopes.length != existing.scope.length) {
        updated.add(user);
      } else {
        unchanged.add(user);
      }
    }
    return BlacklistImportPreview(
      users: users.values.toList(growable: false),
      added: added,
      updated: updated,
      unchanged: unchanged,
    );
  }
}

final serverBlacklistImportProvider = AsyncNotifierProvider.autoDispose<
    ServerBlacklistImportNotifier, BlacklistImportPreview?>(
  ServerBlacklistImportNotifier.new,
);
