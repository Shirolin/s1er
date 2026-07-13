import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/rate_log.dart';
import 'package:s1_app/providers/thread_rate_logs_provider.dart';

void main() {
  group('ThreadRateLogsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('mergePage adds logs by pid', () {
      final notifier = container.read(threadRateLogsProvider('100').notifier);
      notifier.mergePage({
        '1': const PostRateLog(
          pid: '1',
          entries: [RateLog(username: 'a', score: 1)],
          totalScore: 1,
          participantCount: 1,
        ),
      });

      expect(container.read(rateLogProvider(('100', '1'))), isNotNull);
      expect(container.read(rateLogProvider(('100', '2'))), isNull);
    });

    test('clear removes all logs', () {
      final notifier = container.read(threadRateLogsProvider('100').notifier);
      notifier.mergePage({
        '1': const PostRateLog(
          pid: '1',
          entries: [],
          totalScore: 0,
          participantCount: 0,
        ),
      });
      notifier.clear();

      expect(container.read(threadRateLogsProvider('100')), isEmpty);
    });

    test('setForPid replaces single pid', () {
      final notifier = container.read(threadRateLogsProvider('100').notifier);
      notifier.setForPid(
        '1',
        const PostRateLog(
          pid: '1',
          entries: [RateLog(username: 'b', score: 2)],
          totalScore: 2,
          participantCount: 1,
        ),
      );

      final log = container.read(rateLogProvider(('100', '1')));
      expect(log?.totalScore, 2);
    });
  });
}
