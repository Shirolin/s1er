import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/reading_record.dart';
import 'app_database.dart';
import 'settings_store.dart';

/// Local structured data: in-memory mirrors + Drift write-through.
class AppLocalData {
  AppLocalData(this.db) : settings = SettingsStore(db);

  final AppDatabase db;
  final SettingsStore settings;

  /// key = `{uid}_{tid}` → record JSON map
  final Map<String, Map<String, dynamic>> readingHistory = {};

  /// key = `{uid}_{tid}` → option ids
  final Map<String, List<String>> pollVotes = {};

  Future<void> load() async {
    await settings.load();

    readingHistory.clear();
    final historyRows = await db.select(db.readingHistories).get();
    for (final row in historyRows) {
      readingHistory['${row.uid}_${row.tid}'] = {
        'tid': row.tid,
        'subject': row.subject,
        'author': row.author,
        'fid': row.fid,
        'lastReadPage': row.lastReadPage,
        'lastReadFloor': row.lastReadFloor,
        'totalPages': row.totalPages,
        'totalReplies': row.totalReplies,
        'perPage': row.perPage,
        'lastReadAt': row.lastReadAt,
        'firstReadAt': row.firstReadAt,
        'readCount': row.readCount,
      };
    }

    pollVotes.clear();
    final voteRows = await db.select(db.pollVotes).get();
    for (final row in voteRows) {
      try {
        final decoded = jsonDecode(row.optionIdsJson);
        if (decoded is List) {
          pollVotes['${row.uid}_${row.tid}'] = decoded
              .map((e) => e.toString())
              .where((id) => id.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
  }

  void putReadingRecord(String uid, ReadingRecord record) {
    final key = '${uid}_${record.tid}';
    final json = record.toJson();
    readingHistory[key] = json;
    unawaited(
      db.into(db.readingHistories).insertOnConflictUpdate(
            ReadingHistoriesCompanion.insert(
              uid: uid,
              tid: record.tid,
              subject: Value(record.subject),
              author: Value(record.author),
              fid: Value(record.fid),
              lastReadPage: Value(record.lastReadPage),
              lastReadFloor: Value(record.lastReadFloor),
              totalPages: Value(record.totalPages),
              totalReplies: Value(record.totalReplies),
              perPage: Value(record.perPage),
              lastReadAt: record.lastReadAt,
              firstReadAt: record.firstReadAt,
              readCount: Value(record.readCount),
            ),
          ),
    );
  }

  void deleteReadingRecord(String uid, String tid) {
    readingHistory.remove('${uid}_$tid');
    unawaited(
      (db.delete(db.readingHistories)
            ..where((t) => t.uid.equals(uid) & t.tid.equals(tid)))
          .go(),
    );
  }

  Future<void> clearReadingRecords(String uid) async {
    final keys =
        readingHistory.keys.where((k) => k.startsWith('${uid}_')).toList();
    for (final key in keys) {
      readingHistory.remove(key);
    }
    await (db.delete(db.readingHistories)..where((t) => t.uid.equals(uid))).go();
  }

  void putPollVotes(String uid, String tid, List<String> optionIds) {
    pollVotes['${uid}_$tid'] = List<String>.from(optionIds);
    unawaited(
      db.into(db.pollVotes).insertOnConflictUpdate(
            PollVotesCompanion.insert(
              uid: uid,
              tid: tid,
              optionIdsJson: jsonEncode(optionIds),
            ),
          ),
    );
  }

  Future<void> clearPollVotes(String uid) async {
    final keys =
        pollVotes.keys.where((k) => k.startsWith('${uid}_')).toList();
    for (final key in keys) {
      pollVotes.remove(key);
    }
    await (db.delete(db.pollVotes)..where((t) => t.uid.equals(uid))).go();
  }
}
