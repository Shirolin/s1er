import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/rate_log.dart';
import 'post_provider.dart';

typedef RateLogKey = (String tid, String pid);

class ThreadRateLogsNotifier extends Notifier<Map<String, PostRateLog>> {
  ThreadRateLogsNotifier(this.tid);

  final String tid;
  int? _loadedPage;
  final Map<int, _RateLogPageCache> _pageCache = {};
  final Map<int, Future<void>> _inFlightPages = {};

  @override
  Map<String, PostRateLog> build() {
    final link = ref.keepAlive();
    final timer = Timer(S1Constants.cacheExpiry, link.close);
    ref.onDispose(timer.cancel);
    return const {};
  }

  void clear() {
    _loadedPage = null;
    _pageCache.clear();
    _inFlightPages.clear();
    state = const {};
  }

  void mergePage(Map<String, PostRateLog> rateLogs) {
    if (rateLogs.isEmpty) return;
    state = {...state, ...rateLogs};
  }

  void replacePage(Map<String, PostRateLog> rateLogs) {
    state = rateLogs;
  }

  void setForPid(String pid, PostRateLog log) {
    state = {...state, pid: log};
  }

  Future<void> ensurePageRateLogs(int page, {bool force = false}) {
    final cached = _pageCache[page];
    if (!force && cached != null && !cached.isExpired) {
      _loadedPage = page;
      replacePage(cached.logs);
      return Future.value();
    }

    final inFlight = _inFlightPages[page];
    if (inFlight != null) return inFlight;

    late final Future<void> future;
    future = _fetchPage(page).whenComplete(() {
      _inFlightPages.remove(page);
    });
    _inFlightPages[page] = future;
    return future;
  }

  Future<void> _fetchPage(int page) async {
    final service = ref.read(rateLogServiceProvider);
    final rateLogs = await service.fetchRateLogs(tid, page: page);
    if (!ref.mounted) return;
    _pageCache[page] = _RateLogPageCache(rateLogs, DateTime.now());
    replacePage(rateLogs);
    _loadedPage = page;
  }

  Future<void> loadFullRateLog(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    final full = await service.fetchFullRateLog(tid, pid);
    if (!ref.mounted || full == null) return;
    setForPid(pid, full);
    final page = _loadedPage;
    if (page != null) {
      final cached = _pageCache[page];
      if (cached != null) {
        _pageCache[page] = _RateLogPageCache(
          {...cached.logs, pid: full},
          DateTime.now(),
        );
      }
    }
  }
}

class _RateLogPageCache {
  const _RateLogPageCache(this.logs, this.loadedAt);

  final Map<String, PostRateLog> logs;
  final DateTime loadedAt;

  bool get isExpired =>
      DateTime.now().difference(loadedAt) >= S1Constants.cacheExpiry;
}

final threadRateLogsProvider = NotifierProvider.autoDispose
    .family<ThreadRateLogsNotifier, Map<String, PostRateLog>, String>(
  ThreadRateLogsNotifier.new,
);

/// 按 (tid, pid) 订阅单条评分日志。
final rateLogProvider = Provider.autoDispose.family<PostRateLog?, RateLogKey>(
  (ref, key) {
    final (tid, pid) = key;
    return ref.watch(threadRateLogsProvider(tid).select((logs) => logs[pid]));
  },
);
