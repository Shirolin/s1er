import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/rate_log.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/services/rate_log_service.dart';

void main() {
  group('ThreadRateLogsNotifier', () {
    late ProviderContainer container;
    late _FakeRateLogService service;

    setUp(() {
      clearRateLogSessionCacheForTest();
      service = _FakeRateLogService();
      container = ProviderContainer(
        overrides: [rateLogServiceProvider.overrideWithValue(service)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    ThreadRateLogsNotifier notifierFor(String tid) {
      final sub = container.listen(threadRateLogsProvider(tid), (_, __) {});
      addTearDown(sub.close);
      return container.read(threadRateLogsProvider(tid).notifier);
    }

    test('ensureRateLogs fetches each marked pid once and merges', () async {
      service.responses['1'] = _log('1', 2);
      service.responses['2'] = _log('2', 3);
      final notifier = notifierFor('100');

      await notifier.ensureRateLogs(['1', '2', '1']);

      expect(service.requestedPids, ['1', '2']);
      expect(container.read(rateLogProvider(('100', '1')))?.totalScore, 2);
      expect(container.read(rateLogProvider(('100', '2')))?.totalScore, 3);
      expect(container.read(rateLogProvider(('100', '3'))), isNull);
    });

    test('second call hits the session cache', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');

      await notifier.ensureRateLogs(['1']);
      await notifier.ensureRateLogs(['1']);

      expect(service.requestedPids, ['1']);
    });

    test('null response is not cached so the next visit retries', () async {
      final notifier = notifierFor('100');

      await notifier.ensureRateLogs(['9']);
      await notifier.ensureRateLogs(['9']);

      expect(service.requestedPids, ['9', '9']);
      expect(container.read(rateLogProvider(('100', '9'))), isNull);
    });

    test('clear removes state and session cache', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');
      await notifier.ensureRateLogs(['1']);

      notifier.clear();
      expect(container.read(threadRateLogsProvider('100')), isEmpty);

      await notifier.ensureRateLogs(['1']);
      expect(service.requestedPids, ['1', '1']);
    });

    test('loadFullRateLog refreshes one pid and caches it', () async {
      service.responses['1'] = _log('1', 5);
      final notifier = notifierFor('100');

      await notifier.loadFullRateLog('1');

      expect(container.read(rateLogProvider(('100', '1')))?.totalScore, 5);

      await notifier.ensureRateLogs(['1']);
      expect(service.requestedPids, ['1']);
    });

    test('setForPid replaces a single pid', () {
      final notifier = notifierFor('100');

      notifier.setForPid(
        '1',
        const PostRateLog(
          pid: '1',
          entries: [RateLog(username: 'b', score: 2)],
          totalScore: 2,
          participantCount: 1,
        ),
      );

      expect(container.read(rateLogProvider(('100', '1')))?.totalScore, 2);
    });
  });
}

PostRateLog _log(String pid, int score) {
  return PostRateLog(
    pid: pid,
    entries: [RateLog(username: 'u$pid', score: score)],
    totalScore: score,
    participantCount: 1,
  );
}

class _FakeRateLogService extends RateLogService {
  _FakeRateLogService() : super(S1HttpClient.test(null, Dio()));

  final List<String> requestedPids = [];
  final Map<String, PostRateLog> responses = {};

  @override
  Future<PostRateLog?> fetchFullRateLog(String tid, String pid) async {
    requestedPids.add(pid);
    return responses[pid];
  }
}
