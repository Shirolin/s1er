import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/reading_record.dart';
import 'app_database.dart';
import 'settings_store.dart';

/// Local structured data: in-memory mirrors + Drift write-through.
class AppLocalData {
  AppLocalData(this.db) : settings = SettingsStore(db);

  static const Duration _writeDebounce = Duration(milliseconds: 400);

  final AppDatabase db;
  final SettingsStore settings;

  /// key = `{uid}_{tid}` → record JSON map
  final Map<String, Map<String, dynamic>> readingHistory = {};

  /// key = `{uid}_{tid}` → option ids
  final Map<String, List<String>> pollVotes = {};

  bool _readingHistoryLoaded = false;
  bool _pollVotesLoaded = false;
  Future<void>? _readingHistoryLoad;
  Future<void>? _pollVotesLoad;
  final Map<String, Timer> _pendingReadingWrites = {};
  final Map<String, ReadingRecord> _pendingReadingRecords = {};

  /// Settings only — used at cold start.
  Future<void> loadEssentials() async {
    await settings.load();
  }

  /// Test helper: essentials + all lazy tables (always reloads from DB).
  Future<void> load() async {
    await loadEssentials();
    _readingHistoryLoaded = false;
    _pollVotesLoaded = false;
    _readingHistoryLoad = null;
    _pollVotesLoad = null;
    await ensureAllLoaded();
  }

  Future<void> ensureReadingHistoryLoaded() async {
    if (_readingHistoryLoaded) return;
    _readingHistoryLoad ??= _loadReadingHistory();
    await _readingHistoryLoad;
  }

  Future<void> ensurePollVotesLoaded() async {
    if (_pollVotesLoaded) return;
    _pollVotesLoad ??= _loadPollVotes();
    await _pollVotesLoad;
  }

  Future<void> ensureAllLoaded() async {
    await Future.wait([
      ensureReadingHistoryLoaded(),
      ensurePollVotesLoaded(),
    ]);
  }

  Future<void> _loadReadingHistory() async {
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
    _readingHistoryLoaded = true;
  }

  Future<void> _loadPollVotes() async {
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
    _pollVotesLoaded = true;
  }

  void putReadingRecord(String uid, ReadingRecord record) {
    final key = '${uid}_${record.tid}';
    final json = record.toJson();
    readingHistory[key] = json;
    _pendingReadingRecords[key] = record;
    _pendingReadingWrites[key]?.cancel();
    _pendingReadingWrites[key] = Timer(_writeDebounce, () {
      unawaited(_flushReadingRecordKey(key, uid));
    });
  }

  Future<void> _flushReadingRecordKey(String key, String uid) async {
    _pendingReadingWrites.remove(key);
    final record = _pendingReadingRecords.remove(key);
    if (record == null) return;
    await db.into(db.readingHistories).insertOnConflictUpdate(
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
        );
  }

  Future<void> flushPendingWrites() async {
    final keys = _pendingReadingWrites.keys.toList();
    for (final key in keys) {
      _pendingReadingWrites.remove(key)?.cancel();
      final sep = key.indexOf('_');
      if (sep <= 0) continue;
      final uid = key.substring(0, sep);
      await _flushReadingRecordKey(key, uid);
    }
  }

  void deleteReadingRecord(String uid, String tid) {
    final key = '${uid}_$tid';
    _pendingReadingWrites.remove(key)?.cancel();
    _pendingReadingRecords.remove(key);
    readingHistory.remove(key);
    unawaited(
      (db.delete(db.readingHistories)
            ..where((t) => t.uid.equals(uid) & t.tid.equals(tid)))
          .go(),
    );
  }

  Future<void> clearReadingRecords(String uid) async {
    await flushPendingWrites();
    final keys =
        readingHistory.keys.where((k) => k.startsWith('${uid}_')).toList();
    for (final key in keys) {
      _pendingReadingWrites.remove(key)?.cancel();
      _pendingReadingRecords.remove(key);
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
