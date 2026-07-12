import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/services/poll_vote_cache.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
  });

  tearDown(() async {
    await db.close();
  });

  test('saveVotes and getVotes round-trip per user/tid', () async {
    final cache = PollVoteCache(local, '426519');
    await cache.saveVotes('2285124', ['82381']);

    expect(cache.getVotes('2285124'), ['82381']);
    expect(cache.getVotes('999'), isEmpty);
  });

  test('votes are isolated by uid', () async {
    final cacheA = PollVoteCache(local, '1');
    final cacheB = PollVoteCache(local, '2');
    await cacheA.saveVotes('100', ['11']);
    await cacheB.saveVotes('100', ['22']);

    expect(cacheA.getVotes('100'), ['11']);
    expect(cacheB.getVotes('100'), ['22']);
  });

  test('clearAll only clears current uid cache entries', () async {
    final cacheA = PollVoteCache(local, '1');
    final cacheB = PollVoteCache(local, '2');
    await cacheA.saveVotes('100', ['11']);
    await cacheA.saveVotes('101', ['12']);
    await cacheB.saveVotes('100', ['22']);

    await cacheA.clearAll();

    expect(cacheA.getVotes('100'), isEmpty);
    expect(cacheA.getVotes('101'), isEmpty);
    expect(cacheB.getVotes('100'), ['22']);
  });
}
