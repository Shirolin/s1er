import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/rate_log.dart';
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

    test('markPids records only non-empty pids', () {
      final notifier = notifierFor('100');

      notifier.markPids(['1', '', '2']);

      expect(notifier.isMarked('1'), isTrue);
      expect(notifier.isMarked('2'), isTrue);
      expect(notifier.isMarked(''), isFalse);
      expect(notifier.isMarked('3'), isFalse);
    });

    test('ensureRateLog fetches one pid and merges the result', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');

      expect(await notifier.ensureRateLog('1'), isTrue);
      expect(service.requestedPids, ['1']);
      expect(container.read(rateLogProvider(('100', '1')))?.totalScore, 2);
    });

    test('concurrent calls for the same pid share one request', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');

      final results = await Future.wait([
        notifier.ensureRateLog('1'),
        notifier.ensureRateLog('1'),
      ]);

      expect(results, [true, true]);
      expect(service.requestedPids, ['1']);
    });

    test('second call hits the session cache', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');

      await notifier.ensureRateLog('1');
      await notifier.ensureRateLog('1');

      expect(service.requestedPids, ['1']);
    });

    test('empty result is cached so it is not refetched', () async {
      final notifier = notifierFor('100');

      expect(await notifier.ensureRateLog('9'), isTrue);
      expect(await notifier.ensureRateLog('9'), isTrue);

      expect(service.requestedPids, ['9']);
      expect(container.read(rateLogProvider(('100', '9'))), isNull);
    });

    test('request failure returns false, is not cached and is retried',
        () async {
      service.failPids.add('1');
      final notifier = notifierFor('100');

      expect(await notifier.ensureRateLog('1'), isFalse);
      expect(await notifier.ensureRateLog('1'), isFalse);

      expect(service.requestedPids, ['1', '1']);
      expect(container.read(rateLogProvider(('100', '1'))), isNull);
    });

    test('refreshRateLog bypasses the session cache', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');
      await notifier.ensureRateLog('1');

      service.responses['1'] = _log('1', 5);
      expect(await notifier.refreshRateLog('1'), isTrue);

      expect(service.requestedPids, ['1', '1']);
      expect(container.read(rateLogProvider(('100', '1')))?.totalScore, 5);
    });

    test('refresh to empty clears the stale entry', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');
      await notifier.ensureRateLog('1');
      expect(container.read(rateLogProvider(('100', '1'))), isNotNull);

      service.responses.remove('1');
      expect(await notifier.refreshRateLog('1'), isTrue);

      expect(container.read(rateLogProvider(('100', '1'))), isNull);
    });

    test('clear removes state, marks and session cache', () async {
      service.responses['1'] = _log('1', 2);
      final notifier = notifierFor('100');
      notifier.markPids(['1']);
      await notifier.ensureRateLog('1');

      notifier.clear();
      expect(container.read(threadRateLogsProvider('100')), isEmpty);
      expect(notifier.isMarked('1'), isFalse);

      await notifier.ensureRateLog('1');
      expect(service.requestedPids, ['1', '1']);
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
  final Set<String> failPids = {};
  final Map<String, PostRateLog> responses = {};

  @override
  Future<PostRateLog?> fetchRateLog(String tid, String pid) async {
    requestedPids.add(pid);
    if (failPids.contains(pid)) {
      throw DioException(requestOptions: RequestOptions(path: '/rate-log'));
    }
    return responses[pid];
  }
}
