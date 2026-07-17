import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedReadingHistory() async {
    await db.into(db.readingHistories).insert(
          ReadingHistoriesCompanion.insert(
            uid: 'u1',
            tid: '100',
            subject: const Value('subject'),
            author: const Value('alice'),
            fid: const Value('4'),
            lastReadPage: const Value(2),
            lastReadFloor: const Value(45),
            totalPages: const Value(10),
            totalReplies: const Value(100),
            perPage: const Value(40),
            lastReadAt: 1710000000000,
            firstReadAt: 1700000000000,
            readCount: const Value(3),
          ),
        );
  }

  Future<void> seedPollVotes() async {
    await db.into(db.pollVotes).insert(
          PollVotesCompanion.insert(
            uid: 'u1',
            tid: '100',
            optionIdsJson: '["82381"]',
          ),
        );
  }

  test('loadEssentials does not load lazy tables', () async {
    await seedReadingHistory();
    await seedPollVotes();

    await local.loadEssentials();

    expect(local.readingHistory, isEmpty);
    expect(local.pollVotes, isEmpty);
  });

  test('ensureReadingHistoryLoaded is idempotent', () async {
    await seedReadingHistory();
    await local.loadEssentials();

    await local.ensureReadingHistoryLoaded();
    expect(local.readingHistory['u1_100']?['subject'], 'subject');

    local.readingHistory['u1_100']!['subject'] = 'mutated';
    await local.ensureReadingHistoryLoaded();
    expect(local.readingHistory['u1_100']?['subject'], 'mutated');
  });

  test('ensurePollVotesLoaded loads poll votes', () async {
    await seedPollVotes();
    await local.loadEssentials();

    await local.ensurePollVotesLoaded();

    expect(local.pollVotes['u1_100'], ['82381']);
  });

  test('ensureAllLoaded loads both lazy tables', () async {
    await seedReadingHistory();
    await seedPollVotes();
    await local.loadEssentials();

    await local.ensureAllLoaded();

    expect(local.readingHistory['u1_100']?['tid'], '100');
    expect(local.pollVotes['u1_100'], ['82381']);
  });

  test('load helper loads essentials and all tables', () async {
    await seedReadingHistory();
    await seedPollVotes();

    await local.load();

    expect(local.readingHistory['u1_100']?['tid'], '100');
    expect(local.pollVotes['u1_100'], ['82381']);
  });
}
