import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/reading_history_service.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
  });

  tearDown(() async {
    await local.flushPendingWrites();
    await db.close();
  });

  ReadingHistoryService service(String uid) =>
      ReadingHistoryService(local, uid);

  void record(
    ReadingHistoryService s,
    String tid, {
    int page = 1,
    int totalPages = 3,
    bool isNewVisit = true,
  }) {
    s.updateProgress(
      tid: tid,
      page: page,
      floorInPage: 5,
      subject: '主题$tid',
      author: 'a',
      fid: '4',
      totalPages: totalPages,
      totalReplies: 100,
      perPage: 40,
      isNewVisit: isNewVisit,
    );
  }

  test('创建记录并计算绝对楼层', () {
    final s = service('u1');
    record(s, '100', page: 2);
    final r = s.getRecord('100');
    expect(r, isNotNull);
    expect(r!.lastReadPage, 2);
    expect(r.lastReadFloor, 45);
    expect(r.readCount, 1);
  });

  test('readCount 仅在 isNewVisit 时递增（翻页不计）', () {
    final s = service('u1');
    record(s, '100', page: 1, isNewVisit: true);
    record(s, '100', page: 2, isNewVisit: false);
    expect(s.getRecord('100')!.readCount, 1);
    record(s, '100', page: 1, isNewVisit: true);
    expect(s.getRecord('100')!.readCount, 2);
  });

  test('firstReadAt 在更新时保持不变', () {
    final s = service('u1');
    record(s, '100');
    final first = s.getRecord('100')!.firstReadAt;
    record(s, '100', page: 2, isNewVisit: false);
    expect(s.getRecord('100')!.firstReadAt, first);
  });

  test('getAllRecords 按 lastReadAt 倒序', () async {
    final s = service('u1');
    record(s, 'A');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    record(s, 'B');
    final all = s.getAllRecords();
    expect(all.map((e) => e.tid).toList(), ['B', 'A']);
  });

  test('多账号隔离：仅返回/清空当前 uid 的记录', () async {
    final u1 = service('u1');
    final guest = service('guest');
    record(u1, '100');
    record(guest, '200');

    expect(u1.getAllRecords().map((e) => e.tid), ['100']);
    expect(guest.getAllRecords().map((e) => e.tid), ['200']);
    expect(u1.count, 1);

    await u1.clearAll();
    expect(u1.getAllRecords(), isEmpty);
    expect(guest.getRecord('200'), isNotNull);
  });

  test('deleteRecord 只删当前用户对应 tid', () {
    final s = service('u1');
    record(s, '100');
    record(s, '101');
    s.deleteRecord('100');
    expect(s.getRecord('100'), isNull);
    expect(s.getRecord('101'), isNotNull);
  });

  test('超过上限按 lastReadAt 淘汰最旧（按 uid 计数）', () async {
    final s = service('u1');
    for (var i = 0; i < ReadingHistoryService.maxRecords + 2; i++) {
      record(s, 't$i');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(s.count, ReadingHistoryService.maxRecords);
    expect(s.getRecord('t0'), isNull);
    expect(s.getRecord('t1'), isNull);
    expect(s.getRecord('t2'), isNotNull);
  });

  test('migrateGuestRecords moves guest keys to uid prefix', () {
    final guest = service('guest');
    record(guest, '42');
    expect(guest.getRecord('42'), isNotNull);

    final user = ReadingHistoryService(local, '10001');
    user.migrateGuestRecords('10001');

    expect(guest.getRecord('42'), isNull);
    expect(user.getRecord('42'), isNotNull);
  });
}
