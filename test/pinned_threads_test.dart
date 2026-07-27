import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:s1er/providers/pinned_threads_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/backup/s1_backup_codec.dart';
import 'package:s1er/services/backup/s1_backup_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  late AppDatabase db;
  late AppLocalData localData;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    localData = AppLocalData(db);
    await localData.load();
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(localData),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PinnedThreadsNotifier', () {
    test('initial state is empty', () {
      final container = createContainer();
      final threads = container.read(pinnedThreadsProvider);
      expect(threads, isEmpty);
    });

    test('pin thread adds to list and persists', () {
      final container = createContainer();
      final notifier = container.read(pinnedThreadsProvider.notifier);

      final ok = notifier.pin(tid: '123456', title: '测试帖子');
      expect(ok, isTrue);

      final threads = container.read(pinnedThreadsProvider);
      expect(threads.length, equals(1));
      expect(threads.first.tid, equals('123456'));
      expect(threads.first.title, equals('测试帖子'));
      expect(notifier.isPinned('123456'), isTrue);
    });

    test('pin thread limit (max 10)', () {
      final container = createContainer();
      final notifier = container.read(pinnedThreadsProvider.notifier);

      for (var i = 1; i <= 10; i++) {
        final ok = notifier.pin(tid: '$i', title: '帖子 $i');
        expect(ok, isTrue);
      }

      final eleventh = notifier.pin(tid: '11', title: '帖子 11');
      expect(eleventh, isFalse);
      expect(container.read(pinnedThreadsProvider).length, equals(10));
    });

    test('unpin thread removes from list', () {
      final container = createContainer();
      final notifier = container.read(pinnedThreadsProvider.notifier);

      notifier.pin(tid: '100', title: '帖子 100');
      notifier.pin(tid: '200', title: '帖子 200');

      expect(container.read(pinnedThreadsProvider).length, equals(2));

      notifier.unpin('100');
      final threads = container.read(pinnedThreadsProvider);
      expect(threads.length, equals(1));
      expect(threads.first.tid, equals('200'));
      expect(notifier.isPinned('100'), isFalse);
    });

    test('reorder updates displayOrder', () {
      final container = createContainer();
      final notifier = container.read(pinnedThreadsProvider.notifier);

      notifier.pin(tid: 'A', title: 'A');
      notifier.pin(tid: 'B', title: 'B');

      final current = container.read(pinnedThreadsProvider);
      final reordered = [current[1], current[0]];
      notifier.reorder(reordered);

      final updated = container.read(pinnedThreadsProvider);
      expect(updated[0].tid, equals('B'));
      expect(updated[0].displayOrder, equals(0));
      expect(updated[1].tid, equals('A'));
      expect(updated[1].displayOrder, equals(1));
    });

    test('build trims over-limit entries from storage', () async {
      final overLimit = List.generate(
        12,
        (i) => {
          'tid': '$i',
          'title': '帖 $i',
          'pinned_at': 1,
          'display_order': i,
        },
      );
      localData.savePinnedThreads(overLimit);
      await localData.load();

      final container = createContainer();
      expect(container.read(pinnedThreadsProvider).length, equals(10));
      expect(container.read(pinnedThreadsProvider).first.tid, equals('0'));
    });
  });

  group('S1Backup integration', () {
    test('export and import pinnedThreads', () async {
      final container = createContainer();
      final notifier = container.read(pinnedThreadsProvider.notifier);
      notifier.pin(tid: '999', title: '备份测试帖');

      final backupService = S1BackupService(localData);
      final packageInfo = PackageInfo(
        appName: 's1er',
        packageName: 'com.example.s1er',
        version: '1.0.0',
        buildNumber: '1',
      );

      final exportResult = await backupService.exportL1(
        uid: 'user1',
        packageInfo: packageInfo,
      );

      // Create a fresh DB + AppLocalData and import
      final newDb = AppDatabase.forTesting(NativeDatabase.memory());
      final newLocalData = AppLocalData(newDb);
      await newLocalData.load();

      final newBackupService = S1BackupService(newLocalData);
      await newBackupService.importL1(exportResult.bytes);

      expect(newLocalData.pinnedThreads.length, equals(1));
      expect(newLocalData.pinnedThreads.first['tid'], equals('999'));
      expect(newLocalData.pinnedThreads.first['title'], equals('备份测试帖'));

      await newDb.close();
    });

    test('import empty pinned_threads clears existing pins', () async {
      localData.savePinnedThreads([
        {
          'tid': '111',
          'title': '旧置顶',
          'pinned_at': 1,
          'display_order': 0,
        },
      ]);
      await localData.load();

      final backupService = S1BackupService(localData);
      await backupService.importPayload(
        S1BackupPayload(
          manifest: {
            'format': s1BackupFormatId,
            'format_version': s1BackupFormatVersion,
            'contents': ['pinned_threads'],
          },
          pinnedThreads: const [],
        ),
      );

      expect(localData.pinnedThreads, isEmpty);
    });

    test('invalidate provider after import reflects new pins', () async {
      final container = createContainer();
      final notifier = container.read(pinnedThreadsProvider.notifier);
      notifier.pin(tid: 'old', title: '旧帖');

      final backupService = S1BackupService(localData);
      await backupService.importPayload(
        S1BackupPayload(
          manifest: {
            'format': s1BackupFormatId,
            'format_version': s1BackupFormatVersion,
            'contents': ['pinned_threads'],
          },
          pinnedThreads: [
            {
              'tid': 'new',
              'title': '新帖',
              'pinned_at': 2,
              'display_order': 0,
            },
          ],
        ),
      );
      container.invalidate(pinnedThreadsProvider);

      final threads = container.read(pinnedThreadsProvider);
      expect(threads.length, equals(1));
      expect(threads.first.tid, equals('new'));
    });
  });
}
