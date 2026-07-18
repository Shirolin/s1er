import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/blacklist_record.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/blacklist_service.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;
  late BlacklistService service;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
    service = BlacklistService(local);
  });

  tearDown(() async {
    await local.flushPendingWrites();
    await db.close();
  });

  test('upsert stores entry with default scopes', () async {
    final entry = service.upsert(
      uid: '100',
      username: 'bob',
      reason: 'noise',
    );
    expect(entry, isNotNull);
    expect(entry!.uid, '100');
    expect(entry.username, 'bob');
    expect(entry.reason, 'noise');
    expect(entry.scope, BlacklistRecord.defaultScopes);
    expect(service.isBlocked('100'), isTrue);
    expect(service.hasScope('100', BlacklistRecord.scopeThread), isTrue);
    expect(service.hasScope('100', BlacklistRecord.scopePm), isFalse);

    await local.flushPendingWrites();
    final rows = await db.select(db.blacklistEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.uid, '100');
  });

  test('upsert ignores empty uid and updates existing', () {
    expect(service.upsert(uid: '  '), isNull);
    service.upsert(uid: '1', username: 'a', scope: [BlacklistRecord.scopePost]);
    final updated = service.upsert(
      uid: '1',
      username: '',
      reason: 'r',
      scope: BlacklistRecord.defaultScopes,
    );
    expect(updated!.username, 'a');
    expect(updated.reason, 'r');
    expect(updated.scope, BlacklistRecord.defaultScopes);
  });

  test('remove and clearAll', () async {
    service.upsert(uid: '1', username: 'a');
    service.upsert(uid: '2', username: 'b');
    expect(service.getAll(), hasLength(2));

    service.remove('1');
    expect(service.isBlocked('1'), isFalse);
    expect(service.getAll().single.uid, '2');

    await service.clearAll();
    expect(service.getAll(), isEmpty);
  });

  test('getAll sorts by createdAt desc', () {
    service.upsert(uid: 'old', createdAt: 10);
    service.upsert(uid: 'new', createdAt: 20);
    expect(service.getAll().map((e) => e.uid).toList(), ['new', 'old']);
  });
}
