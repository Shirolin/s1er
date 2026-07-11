import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s1_app/services/poll_vote_cache.dart';

void main() {
  late Directory tempDir;
  late Box cacheBox;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('poll_vote_cache_test');
    Hive.init(tempDir.path);
    cacheBox = await Hive.openBox('cache');
  });

  tearDown(() async {
    await cacheBox.clear();
  });

  tearDownAll(() async {
    await cacheBox.close();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('saveVotes and getVotes round-trip per user/tid', () async {
    final cache = PollVoteCache(cacheBox, '426519');
    await cache.saveVotes('2285124', ['82381']);

    expect(cache.getVotes('2285124'), ['82381']);
    expect(cache.getVotes('999'), isEmpty);
  });

  test('votes are isolated by uid', () async {
    final cacheA = PollVoteCache(cacheBox, '1');
    final cacheB = PollVoteCache(cacheBox, '2');
    await cacheA.saveVotes('100', ['11']);
    await cacheB.saveVotes('100', ['22']);

    expect(cacheA.getVotes('100'), ['11']);
    expect(cacheB.getVotes('100'), ['22']);
  });

  test('clearAll only clears current uid cache entries', () async {
    final cacheA = PollVoteCache(cacheBox, '1');
    final cacheB = PollVoteCache(cacheBox, '2');
    await cacheA.saveVotes('100', ['11']);
    await cacheA.saveVotes('101', ['12']);
    await cacheB.saveVotes('100', ['22']);

    await cacheA.clearAll();

    expect(cacheA.getVotes('100'), isEmpty);
    expect(cacheA.getVotes('101'), isEmpty);
    expect(cacheB.getVotes('100'), ['22']);
  });
}
