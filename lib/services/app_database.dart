import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

part 'app_database.g.dart';

/// KV settings (JSON-encoded values for bool/int/list/string).
class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class ReadingHistories extends Table {
  TextColumn get uid => text()();
  TextColumn get tid => text()();
  TextColumn get subject => text().withDefault(const Constant(''))();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get fid => text().withDefault(const Constant(''))();
  IntColumn get lastReadPage => integer().withDefault(const Constant(1))();
  IntColumn get lastReadFloor => integer().withDefault(const Constant(1))();
  IntColumn get totalPages => integer().withDefault(const Constant(1))();
  IntColumn get totalReplies => integer().withDefault(const Constant(0))();
  IntColumn get perPage => integer().withDefault(const Constant(0))();
  IntColumn get lastReadAt => integer()();
  IntColumn get firstReadAt => integer()();
  IntColumn get readCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {uid, tid};
}

class PollVotes extends Table {
  TextColumn get uid => text()();
  TextColumn get tid => text()();
  TextColumn get optionIdsJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {uid, tid};
}

/// Local blacklist of forum users (device-wide; see BlacklistService).
class BlacklistEntries extends Table {
  TextColumn get uid => text()();
  TextColumn get username => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get scopeJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {uid};
}

@DriftDatabase(
  tables: [
    SettingsEntries,
    ReadingHistories,
    PollVotes,
    BlacklistEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openExecutor());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openExecutor() {
    return driftDatabase(
      name: 's1_app',
      web: kIsWeb
          ? DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            )
          : null,
    );
  }

  // --- settings helpers ---

  Future<String?> getSetting(String key) async {
    final row = await (select(settingsEntries)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, Object? value) async {
    if (value == null) {
      await (delete(settingsEntries)..where((t) => t.key.equals(key))).go();
      return;
    }
    await into(settingsEntries).insertOnConflictUpdate(
      SettingsEntriesCompanion.insert(key: key, value: jsonEncode(value)),
    );
  }

  T? decodeSetting<T>(String? raw, T? Function(Object? json) cast) {
    if (raw == null) return null;
    try {
      return cast(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
