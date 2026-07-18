import 'dart:async';
import 'dart:convert';

import 'app_database.dart';
import 'talker.dart';

/// In-memory settings with async Drift persistence (sync reads).
class SettingsStore {
  SettingsStore(this._db);

  final AppDatabase _db;
  final Map<String, Object?> _cache = {};

  Future<void> load() async {
    final rows = await _db.select(_db.settingsEntries).get();
    _cache.clear();
    for (final row in rows) {
      try {
        _cache[row.key] = jsonDecode(row.value);
      } on FormatException catch (e, st) {
        talker.handle(
          e,
          st,
          'Decode settings cache failed for key: ${row.key}',
        );
        _cache[row.key] = row.value;
      }
    }
  }

  T? get<T>(String key, {T? defaultValue}) {
    final value = _cache[key];
    if (value == null) return defaultValue;
    return value as T?;
  }

  void put(String key, Object? value) {
    if (value == null) {
      _cache.remove(key);
      unawaited(_db.setSetting(key, null));
      return;
    }
    _cache[key] = value;
    unawaited(_db.setSetting(key, value));
  }
}
