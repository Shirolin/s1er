import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/reading_record.dart';
import '../app_database.dart';
import '../app_local_data.dart';
import 's1_backup_codec.dart';

class S1BackupExportResult {
  S1BackupExportResult({
    required this.bytes,
    required this.fileName,
    required this.payload,
  });

  final Uint8List bytes;
  final String fileName;
  final S1BackupPayload payload;
}

class S1BackupImportResult {
  S1BackupImportResult({
    required this.readingHistoryUpserts,
    required this.pollVoteUpserts,
    required this.blacklistUpserts,
    required this.settingsApplied,
  });

  final int readingHistoryUpserts;
  final int pollVoteUpserts;
  final int blacklistUpserts;
  final int settingsApplied;
}

/// L1 export / import against [AppLocalData] (no cookies / image cache).
class S1BackupService {
  S1BackupService(this._local);

  final AppLocalData _local;

  static final _exportSettingKeys = S1BackupSettingsMapper.appToBackup.keys;

  Future<S1BackupExportResult> exportL1({
    required String? uid,
    required PackageInfo packageInfo,
    String platform = 'unknown',
  }) async {
    await _local.ensureAllLoaded();
    final effectiveUid = (uid == null || uid.isEmpty) ? 'guest' : uid;

    final appSettings = <String, Object?>{};
    for (final key in _exportSettingKeys) {
      final value = _local.settings.get<Object>(key);
      if (value != null) appSettings[key] = value;
    }
    appSettings.putIfAbsent('themeMode', () => 'system');
    appSettings.putIfAbsent('themeColor', () => 'purple');
    appSettings.putIfAbsent('showImages', () => true);
    appSettings.putIfAbsent('imageLoadPolicy', () => 'always');
    appSettings.putIfAbsent('avatarLoadPolicy', () => 'always');
    appSettings.putIfAbsent('maxImagesPerPost', () => 10);
    appSettings.putIfAbsent('imageCacheLimitMb', () => 256);
    appSettings.putIfAbsent('recordReadingHistory', () => true);
    appSettings.putIfAbsent('fontSize', () => 14);
    appSettings.putIfAbsent('collapsedForums', () => <String>[]);
    appSettings.putIfAbsent('shareImageFormat', () => 'jpeg');
    appSettings.putIfAbsent('sharePixelRatio', () => 3);

    final settingsJson = S1BackupSettingsMapper.toBackup(appSettings);

    final history = <Map<String, dynamic>>[];
    for (final entry in _local.readingHistory.entries) {
      final sep = entry.key.indexOf('_');
      if (sep <= 0) continue;
      final recordUid = entry.key.substring(0, sep);
      final record = ReadingRecord.fromJson(entry.value);
      history.add({
        'uid': recordUid,
        'tid': record.tid,
        'subject': record.subject,
        'author': record.author,
        'fid': record.fid,
        'last_read_page': record.lastReadPage,
        'last_read_floor': record.lastReadFloor,
        'total_pages': record.totalPages,
        'total_replies': record.totalReplies,
        'per_page': record.perPage,
        'last_read_at': record.lastReadAt,
        'first_read_at': record.firstReadAt,
        'read_count': record.readCount,
      });
    }

    final votes = <Map<String, dynamic>>[];
    for (final entry in _local.pollVotes.entries) {
      final sep = entry.key.indexOf('_');
      if (sep <= 0) continue;
      votes.add({
        'uid': entry.key.substring(0, sep),
        'tid': entry.key.substring(sep + 1),
        'option_ids': entry.value,
      });
    }

    final blacklistRows =
        await _local.db.select(_local.db.blacklistEntries).get();
    final blacklist = <Map<String, dynamic>>[];
    for (final row in blacklistRows) {
      dynamic decoded;
      try {
        decoded = jsonDecode(row.scopeJson);
      } on FormatException {
        throw S1BackupException('黑名单作用域数据损坏，无法导出备份');
      }
      if (decoded is! List) {
        throw S1BackupException('黑名单作用域数据损坏，无法导出备份');
      }
      blacklist.add({
        'uid': row.uid,
        'username': row.username,
        'created_at': row.createdAt,
        'reason': row.reason,
        'scope': decoded,
      });
    }

    const contents = <String>[
      'settings',
      'reading_history',
      'blacklist',
      'poll_votes',
    ];

    final exportedAt = DateTime.now().toUtc();
    final manifest = <String, dynamic>{
      'format': s1BackupFormatId,
      'format_version': s1BackupFormatVersion,
      'exported_at': exportedAt.toIso8601String(),
      'exporter': {
        'name': 's1_app',
        'version': '${packageInfo.version}+${packageInfo.buildNumber}',
        'platform': platform,
      },
      'uid': effectiveUid,
      'contents': contents,
      'counts': {
        'reading_history': history.length,
        'blacklist': blacklist.length,
        'poll_votes': votes.length,
      },
    };

    final payload = S1BackupPayload(
      manifest: manifest,
      settings: settingsJson,
      readingHistory: history,
      blacklist: blacklist,
      pollVotes: votes,
    );

    final bytes = S1BackupCodec.encode(payload);
    return S1BackupExportResult(
      bytes: bytes,
      fileName: '${_fileStamp(exportedAt)}-s1backup.zip',
      payload: payload,
    );
  }

  Future<S1BackupImportResult> importL1(List<int> bytes) {
    return importPayload(S1BackupCodec.decode(Uint8List.fromList(bytes)));
  }

  Future<S1BackupImportResult> importPayload(S1BackupPayload payload) async {
    await _local.ensureAllLoaded();
    var settingsApplied = 0;
    var historyUpserts = 0;
    var voteUpserts = 0;
    var blacklistUpserts = 0;

    await _local.db.transaction(() async {
      if (payload.settings != null) {
        final appSettings = S1BackupSettingsMapper.toApp(payload.settings!);
        for (final entry in appSettings.entries) {
          await _local.db.setSetting(entry.key, entry.value);
          settingsApplied++;
        }
      }

      for (final item in payload.readingHistory) {
        final uid = item['uid']?.toString() ?? '';
        final tid = item['tid']?.toString() ?? '';
        if (uid.isEmpty || tid.isEmpty) continue;
        final record = ReadingRecord(
          tid: tid,
          subject: item['subject']?.toString() ?? '',
          author: item['author']?.toString() ?? '',
          fid: item['fid']?.toString() ?? '',
          lastReadPage:
              _asInt(item['last_read_page'] ?? item['lastReadPage'], 1),
          lastReadFloor:
              _asInt(item['last_read_floor'] ?? item['lastReadFloor'], 1),
          totalPages: _asInt(item['total_pages'] ?? item['totalPages'], 1),
          totalReplies:
              _asInt(item['total_replies'] ?? item['totalReplies'], 0),
          perPage: _asInt(item['per_page'] ?? item['perPage'], 0),
          lastReadAt: _asInt(item['last_read_at'] ?? item['lastReadAt'], 0),
          firstReadAt: _asInt(item['first_read_at'] ?? item['firstReadAt'], 0),
          readCount: _asInt(item['read_count'] ?? item['readCount'], 1),
        );
        await _local.db.into(_local.db.readingHistories).insertOnConflictUpdate(
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
        historyUpserts++;
      }

      for (final item in payload.pollVotes) {
        final uid = item['uid']?.toString() ?? '';
        final tid = item['tid']?.toString() ?? '';
        if (uid.isEmpty || tid.isEmpty) continue;
        final rawIds = item['option_ids'] ?? item['optionIds'];
        final optionIds = rawIds is List
            ? rawIds
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
        if (optionIds.isEmpty) continue;
        await _local.db.into(_local.db.pollVotes).insertOnConflictUpdate(
              PollVotesCompanion.insert(
                uid: uid,
                tid: tid,
                optionIdsJson: jsonEncode(optionIds),
              ),
            );
        voteUpserts++;
      }

      for (final item in payload.blacklist) {
        final uid = item['uid']?.toString() ?? '';
        if (uid.isEmpty) continue;
        final scope = item['scope'];
        final scopeJson = jsonEncode(scope is List ? scope : const []);
        await _local.db.into(_local.db.blacklistEntries).insertOnConflictUpdate(
              BlacklistEntriesCompanion.insert(
                uid: uid,
                username: Value(item['username']?.toString() ?? ''),
                createdAt: _asInt(item['created_at'] ?? item['createdAt'], 0),
                reason: Value(item['reason']?.toString() ?? ''),
                scopeJson: Value(scopeJson),
              ),
            );
        blacklistUpserts++;
      }
    });

    await _local.load();

    return S1BackupImportResult(
      readingHistoryUpserts: historyUpserts,
      pollVoteUpserts: voteUpserts,
      blacklistUpserts: blacklistUpserts,
      settingsApplied: settingsApplied,
    );
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _fileStamp(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}-'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }
}
