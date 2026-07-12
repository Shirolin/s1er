import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'app_local_data.dart';
import 'talker.dart';

/// One-shot Hive → Drift migration. Safe to call every launch; no-ops when done.
class HiveToDriftMigrator {
  HiveToDriftMigrator(this._local);

  final AppLocalData _local;

  static const flagKey = 'migrated_from_hive_v1';

  Future<void> run() async {
    final already = _local.settings.get<bool>(flagKey) ?? false;
    if (already) return;

    try {
      if (!kIsWeb) {
        await _migrateNative();
      }
    } catch (e, st) {
      talker.handle(e, st, 'Hive → Drift migration failed');
    } finally {
      _local.settings.put(flagKey, true);
    }
  }

  Future<void> _migrateNative() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    if (await Hive.boxExists('settings')) {
      final box = await Hive.openBox('settings');
      for (final key in box.keys) {
        final k = key.toString();
        if (k == flagKey) continue;
        final value = box.get(key);
        if (value != null) {
          _local.settings.put(k, value);
        }
      }
      await box.close();
    }

    if (await Hive.boxExists('reading_history')) {
      final box = await Hive.openBox('reading_history');
      for (final key in box.keys) {
        final keyStr = key.toString();
        final sep = keyStr.indexOf('_');
        if (sep <= 0) continue;
        final uid = keyStr.substring(0, sep);
        final tid = keyStr.substring(sep + 1);
        final raw = box.get(key);
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        map['tid'] = map['tid']?.toString() ?? tid;
        _local.readingHistory[keyStr] = map;
        await _local.db.into(_local.db.readingHistories).insertOnConflictUpdate(
              ReadingHistoriesCompanion.insert(
                uid: uid,
                tid: tid,
                subject: Value(map['subject']?.toString() ?? ''),
                author: Value(map['author']?.toString() ?? ''),
                fid: Value(map['fid']?.toString() ?? ''),
                lastReadPage: Value((map['lastReadPage'] as num?)?.toInt() ?? 1),
                lastReadFloor:
                    Value((map['lastReadFloor'] as num?)?.toInt() ?? 1),
                totalPages: Value((map['totalPages'] as num?)?.toInt() ?? 1),
                totalReplies: Value((map['totalReplies'] as num?)?.toInt() ?? 0),
                perPage: Value((map['perPage'] as num?)?.toInt() ?? 0),
                lastReadAt: (map['lastReadAt'] as num?)?.toInt() ?? 0,
                firstReadAt: (map['firstReadAt'] as num?)?.toInt() ?? 0,
                readCount: Value((map['readCount'] as num?)?.toInt() ?? 1),
              ),
            );
      }
      await box.close();
    }

    if (await Hive.boxExists('cache')) {
      final box = await Hive.openBox('cache');
      for (final key in box.keys) {
        final keyStr = key.toString();
        if (!keyStr.startsWith('poll_vote_')) continue;
        final rest = keyStr.substring('poll_vote_'.length);
        final sep = rest.indexOf('_');
        if (sep <= 0) continue;
        final uid = rest.substring(0, sep);
        final tid = rest.substring(sep + 1);
        final raw = box.get(key);
        if (raw is! List) continue;
        final ids = raw.map((e) => e.toString()).toList();
        _local.putPollVotes(uid, tid, ids);
      }
      await box.close();
    }

    await Hive.close();
  }
}
