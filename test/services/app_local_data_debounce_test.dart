import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';

ReadingRecord _sampleRecord({String tid = '100', String subject = 'hello'}) {
  return ReadingRecord(
    tid: tid,
    subject: subject,
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
  );
}

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.loadEssentials();
  });

  tearDown(() async {
    await local.flushPendingWrites();
    await db.close();
  });

  test('putReadingRecord updates memory immediately', () {
    local.putReadingRecord('u1', _sampleRecord());

    expect(local.readingHistory['u1_100']?['subject'], 'hello');
  });

  test('putReadingRecord debounces Drift writes', () async {
    local.putReadingRecord('u1', _sampleRecord());

    final immediate = await db.select(db.readingHistories).get();
    expect(immediate, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 450));

    final persisted = await db.select(db.readingHistories).get();
    expect(persisted, hasLength(1));
    expect(persisted.first.subject, 'hello');
  });

  test('flushPendingWrites persists before debounce elapses', () async {
    local.putReadingRecord('u1', _sampleRecord());

    await local.flushPendingWrites();

    final persisted = await db.select(db.readingHistories).get();
    expect(persisted, hasLength(1));
  });

  test('deleteReadingRecord cancels pending debounced write', () async {
    local.putReadingRecord('u1', _sampleRecord());
    local.deleteReadingRecord('u1', '100');

    await Future<void>.delayed(const Duration(milliseconds: 450));

    final persisted = await db.select(db.readingHistories).get();
    expect(persisted, isEmpty);
    expect(local.readingHistory.containsKey('u1_100'), isFalse);
  });

  test('rapid updates coalesce to one disk write', () async {
    local.putReadingRecord('u1', _sampleRecord(subject: 'first'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    local.putReadingRecord('u1', _sampleRecord(subject: 'second'));
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final persisted = await db.select(db.readingHistories).get();
    expect(persisted, hasLength(1));
    expect(persisted.first.subject, 'second');
  });
}
