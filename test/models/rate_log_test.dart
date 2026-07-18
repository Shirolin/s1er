import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/rate_log.dart';

void main() {
  group('RateLog', () {
    test('isPositive returns true for positive score', () {
      const log = RateLog(username: 'user', score: 2);
      expect(log.isPositive, isTrue);
    });

    test('isPositive returns false for negative score', () {
      const log = RateLog(username: 'user', score: -3);
      expect(log.isPositive, isFalse);
    });

    test('isPositive returns false for zero score', () {
      const log = RateLog(username: 'user', score: 0);
      expect(log.isPositive, isFalse);
    });

    test('defaults reason to empty string', () {
      const log = RateLog(username: 'user', score: 1);
      expect(log.reason, '');
    });
  });

  group('PostRateLog', () {
    test('isEmpty returns true when entries is empty', () {
      const rateLog = PostRateLog(
        pid: '123',
        entries: [],
        totalScore: 0,
        participantCount: 0,
      );
      expect(rateLog.isEmpty, isTrue);
    });

    test('isEmpty returns false when entries is not empty', () {
      const rateLog = PostRateLog(
        pid: '123',
        entries: [RateLog(username: 'user', score: 2)],
        totalScore: 2,
        participantCount: 1,
      );
      expect(rateLog.isEmpty, isFalse);
    });

    test('stores all fields correctly', () {
      const entries = [
        RateLog(username: 'a', score: 2, reason: 'good'),
        RateLog(username: 'b', score: -1, reason: 'bad'),
      ];
      const rateLog = PostRateLog(
        pid: '67953733',
        entries: entries,
        totalScore: 1,
        participantCount: 2,
      );
      expect(rateLog.pid, '67953733');
      expect(rateLog.entries.length, 2);
      expect(rateLog.totalScore, 1);
      expect(rateLog.participantCount, 2);
    });
  });
}
