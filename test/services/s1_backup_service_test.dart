import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1er/models/blacklist_record.dart';
import 'package:s1er/models/reading_record.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/backup/s1_backup_codec.dart';
import 'package:s1er/services/backup/s1_backup_service.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;
  late S1BackupService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
    service = S1BackupService(local);
  });

  tearDown(() async {
    await local.flushPendingWrites();
    await db.close();
  });

  PackageInfo info() => PackageInfo(
        appName: 'S1',
        packageName: 'com.example.s1',
        version: '1.0.0',
        buildNumber: '1',
      );

  group('S1BackupCodec', () {
    test('rejects wrong format', () {
      final wrong = S1BackupPayload(
        manifest: {
          'format': 'nope',
          'format_version': 1,
          'exported_at': '2026-07-12T00:00:00Z',
          'contents': <String>[],
        },
      );
      final bytes = S1BackupCodec.encode(wrong);
      expect(
        () => S1BackupCodec.decode(bytes),
        throwsA(isA<S1BackupException>()),
      );
    });

    test('rejects future format_version', () {
      final payload = S1BackupPayload(
        manifest: {
          'format': s1BackupFormatId,
          'format_version': s1BackupFormatVersion + 1,
          'exported_at': '2026-07-12T00:00:00Z',
          'contents': <String>[],
        },
      );
      final bytes = S1BackupCodec.encode(payload);
      expect(
        () => S1BackupCodec.decode(bytes),
        throwsA(isA<S1BackupException>()),
      );
    });

    test('settings mapper round-trips snake_case', () {
      final backup = S1BackupSettingsMapper.toBackup({
        'themeMode': 'dark',
        'collapsedForums': {'4', '6'},
        'fontSize': 16,
        'imageLoadPolicy': 'wifiOnly',
        'avatarLoadPolicy': 'manual',
        'maxImagesPerPost': 20,
        'imageCacheLimitMb': 512,
        'shareImageFormat': 'png',
        'sharePixelRatio': 2,
      });
      expect(backup['theme_mode'], 'dark');
      expect(backup['collapsed_forums'], isA<List>());
      expect(backup['font_size'], 16);
      expect(backup['image_load_policy'], 'wifi_only');
      expect(backup['avatar_load_policy'], 'manual');
      expect(backup['max_images_per_post'], 20);
      expect(backup['image_cache_limit_mb'], 512);
      expect(backup['share_image_format'], 'png');
      expect(backup['share_pixel_ratio'], 2);
      expect(backup.containsKey('use_dynamic_color'), isFalse);
      expect(backup.containsKey('simulate_dynamic'), isFalse);

      final app = S1BackupSettingsMapper.toApp({
        ...backup,
        'use_dynamic_color': true,
        'simulate_dynamic': true,
        'unknown_field': true,
      });
      expect(app['themeMode'], 'dark');
      expect(app['fontSize'], 16);
      expect(app['imageLoadPolicy'], 'wifiOnly');
      expect(app['avatarLoadPolicy'], 'manual');
      expect(app['maxImagesPerPost'], 20);
      expect(app['imageCacheLimitMb'], 512);
      expect(app['shareImageFormat'], 'png');
      expect(app['sharePixelRatio'], 2);
      expect(app.containsKey('useDynamicColor'), isFalse);
      expect(app.containsKey('simulateDynamic'), isFalse);
      expect(app.containsKey('unknown_field'), isFalse);
    });
  });

  group('S1BackupService L1 round-trip', () {
    test('exports and imports settings, history, votes, empty blacklist',
        () async {
      local.settings.put('themeMode', 'dark');
      local.settings.put('themeColor', 'green');
      local.settings.put('fontSize', 18);
      local.settings.put('collapsedForums', <String>['42']);

      local.putReadingRecord(
        'u1',
        ReadingRecord(
          tid: '100',
          subject: 'hello',
          author: 'alice',
          fid: '4',
          lastReadPage: 2,
          lastReadFloor: 45,
          totalPages: 10,
          totalReplies: 100,
          perPage: 40,
          lastReadAt: 1710000000000,
          firstReadAt: 1700000000000,
          readCount: 3,
        ),
      );
      local.putPollVotes('u1', '100', ['82381']);

      // Allow fire-and-forget writes to land before export reads memory
      // (export uses memory mirrors for history/votes).
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final exported = await service.exportL1(
        uid: 'u1',
        packageInfo: info(),
        platform: 'test',
      );
      expect(exported.fileName, contains('s1backup.zip'));
      expect(exported.payload.blacklist, isEmpty);
      expect(exported.payload.manifest['format'], s1BackupFormatId);

      // Wipe local and re-import
      await local.clearReadingRecords('u1');
      await local.clearPollVotes('u1');
      local.settings.put('themeMode', 'system');
      local.settings.put('themeColor', 'purple');
      local.settings.put('fontSize', 14);
      local.settings.put('collapsedForums', <String>[]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final imported = await service.importL1(exported.bytes);
      expect(imported.settingsApplied, greaterThan(0));
      expect(imported.readingHistoryUpserts, 1);
      expect(imported.pollVoteUpserts, 1);
      expect(imported.blacklistUpserts, 0);

      expect(local.settings.get<String>('themeMode'), 'dark');
      expect(local.settings.get<String>('themeColor'), 'green');
      expect(local.settings.get<int>('fontSize'), 18);
      expect(local.readingHistory['u1_100']?['subject'], 'hello');
      expect(local.pollVotes['u1_100'], ['82381']);
      expect(exported.payload.settings?['use_dynamic_color'], equals(null));
      expect(exported.payload.settings?['simulate_dynamic'], equals(null));
    });

    test('import overwrites same reading history key', () async {
      local.putReadingRecord(
        'u1',
        ReadingRecord(
          tid: '100',
          subject: 'old',
          author: 'a',
          fid: '4',
          lastReadPage: 1,
          lastReadFloor: 1,
          totalPages: 1,
          totalReplies: 0,
          perPage: 40,
          lastReadAt: 1,
          firstReadAt: 1,
        ),
      );

      final payload = S1BackupPayload(
        manifest: {
          'format': s1BackupFormatId,
          'format_version': 1,
          'exported_at': '2026-07-12T00:00:00Z',
          'contents': ['reading_history'],
        },
        readingHistory: [
          {
            'uid': 'u1',
            'tid': '100',
            'subject': 'new',
            'author': 'b',
            'fid': '4',
            'last_read_page': 3,
            'last_read_floor': 9,
            'total_pages': 5,
            'total_replies': 20,
            'per_page': 40,
            'last_read_at': 99,
            'first_read_at': 1,
            'read_count': 2,
          },
        ],
      );

      await service.importPayload(payload);
      expect(local.readingHistory['u1_100']?['subject'], 'new');
      expect(local.readingHistory['u1_100']?['lastReadPage'], 3);
    });

    test('decode ignores missing optional files', () {
      final payload = S1BackupPayload(
        manifest: {
          'format': s1BackupFormatId,
          'format_version': 1,
          'exported_at': '2026-07-12T00:00:00Z',
          'contents': ['settings'],
        },
        settings: {'theme_mode': 'light'},
      );
      final bytes = S1BackupCodec.encode(payload);
      final decoded = S1BackupCodec.decode(Uint8List.fromList(bytes));
      expect(decoded.settings?['theme_mode'], 'light');
      expect(decoded.readingHistory, isEmpty);
      expect(decoded.blacklist, isEmpty);
    });

    test('exports and imports non-empty blacklist', () async {
      local.putBlacklistRecord(
        const BlacklistRecord(
          uid: '55',
          username: 'blocked',
          createdAt: 1710000000000,
          reason: 'spam',
          scope: ['thread', 'post', 'pm'],
        ),
      );
      await local.flushPendingWrites();

      final exported = await service.exportL1(
        uid: 'u1',
        packageInfo: info(),
        platform: 'test',
      );
      expect(exported.payload.blacklist, hasLength(1));
      expect(exported.payload.blacklist.first['uid'], '55');
      expect(
        exported.payload.blacklist.first['scope'],
        ['thread', 'post', 'pm'],
      );

      await local.clearBlacklist();
      await local.flushPendingWrites();
      expect(local.blacklist, isEmpty);

      final imported = await service.importL1(exported.bytes);
      expect(imported.blacklistUpserts, 1);
      expect(local.blacklist['55']?.username, 'blocked');
      expect(local.blacklist['55']?.reason, 'spam');
      expect(local.blacklist['55']?.scope, ['thread', 'post', 'pm']);
    });

    test('export rejects corrupted blacklist scope json', () async {
      await db.into(db.blacklistEntries).insert(
            BlacklistEntriesCompanion.insert(
              uid: 'u1',
              username: const Value('alice'),
              createdAt: 1,
              reason: const Value('bad data'),
              scopeJson: const Value('{oops'),
            ),
          );

      await expectLater(
        service.exportL1(
          uid: 'u1',
          packageInfo: info(),
          platform: 'test',
        ),
        throwsA(isA<S1BackupException>()),
      );
    });
  });
}
