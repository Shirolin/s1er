import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/reading_history_coordinator.dart';
import 'package:s1_app/providers/reading_history_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/services/reading_history_service.dart';

ReadingRecord _sample(String tid, {int lastReadAt = 1000}) {
  return ReadingRecord(
    tid: tid,
    subject: '主题$tid',
    author: 'a',
    fid: '4',
    lastReadPage: 1,
    lastReadFloor: 1,
    totalPages: 3,
    totalReplies: 80,
    perPage: 40,
    lastReadAt: lastReadAt,
    firstReadAt: lastReadAt,
  );
}

void main() {
  late AppDatabase db;
  late AppLocalData local;
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
    container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('upsert inserts and sorts by lastReadAt desc', () {
    final notifier = container.read(readingHistoryProvider.notifier);
    notifier.upsert(_sample('A', lastReadAt: 100));
    notifier.upsert(_sample('B', lastReadAt: 200));

    final list = container.read(readingHistoryProvider).records;
    expect(list.map((e) => e.tid).toList(), ['B', 'A']);
  });

  test('upsert replaces existing tid', () {
    final notifier = container.read(readingHistoryProvider.notifier);
    notifier.upsert(_sample('A', lastReadAt: 100));
    notifier.upsert(
      _sample('A', lastReadAt: 300).copyWith(lastReadPage: 2),
    );

    final list = container.read(readingHistoryProvider).records;
    expect(list.length, 1);
    expect(list.single.lastReadPage, 2);
    expect(list.single.lastReadAt, 300);
  });

  test('delete removes tid from state', () {
    final notifier = container.read(readingHistoryProvider.notifier);
    notifier.upsert(_sample('A'));
    notifier.upsert(_sample('B'));
    notifier.delete('A');

    final list = container.read(readingHistoryProvider).records;
    expect(list.map((e) => e.tid).toList(), ['B']);
    expect(
      container.read(readingHistoryServiceProvider).getRecord('A'),
      isNull,
    );
  });

  test('readingRecordProvider reflects upsert for single tid', () {
    final notifier = container.read(readingHistoryProvider.notifier);
    notifier.upsert(_sample('42', lastReadAt: 500));

    final record = container.read(readingRecordProvider('42'));
    expect(record, isNotNull);
    expect(record!.tid, '42');
    expect(container.read(readingRecordProvider('99')), isNull);
  });

  test('clearAll empties state', () async {
    final notifier = container.read(readingHistoryProvider.notifier);
    notifier.upsert(_sample('A'));
    await notifier.clearAll();
    expect(container.read(readingHistoryProvider).isEmpty, isTrue);
  });

  test('currentReadingUidProvider returns guest when logged out', () {
    container.read(readingHistoryCoordinatorProvider);
    expect(container.read(currentReadingUidProvider), 'guest');
  });

  test('currentReadingUidProvider follows auth uid', () {
    container.read(readingHistoryCoordinatorProvider);
    container.read(authStateProvider.notifier).debugSetState(
          AuthState(
            isLoggedIn: true,
            username: 'alice',
            user: User(uid: 'u1', username: 'alice'),
          ),
        );
    expect(container.read(currentReadingUidProvider), 'u1');
  });

  test('service uses guest namespace when logged out', () {
    ReadingHistoryService(local, 'guest').updateProgress(
      tid: '7',
      page: 1,
      floorInPage: 1,
      subject: 's',
      author: 'a',
      fid: '4',
      totalPages: 1,
      totalReplies: 0,
      perPage: 40,
    );
    container.read(readingHistoryCoordinatorProvider);
    expect(
      container.read(readingHistoryServiceProvider).getRecord('7'),
      isNotNull,
    );
  });
}
