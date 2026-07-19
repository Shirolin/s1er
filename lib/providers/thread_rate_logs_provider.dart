import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/rate_log.dart';
import 'post_provider.dart';

typedef RateLogKey = (String tid, String pid);

/// 进程内会话缓存：不依赖 keepAlive Timer，避免 widget 测试残留定时器。
class _RateLogSessionStore {
  _RateLogSessionStore._();

  static final Map<(String tid, int page), _RateLogPageCache> _pages = {};

  static Map<String, PostRateLog>? get(String tid, int page) {
    final key = (tid, page);
    final cached = _pages[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.loadedAt) >=
        S1Constants.postSessionCacheExpiry) {
      _pages.remove(key);
      return null;
    }
    return cached.logs;
  }

  static void put(String tid, int page, Map<String, PostRateLog> logs) {
    _pages[(tid, page)] = _RateLogPageCache(logs, DateTime.now());
  }

  static void updatePid(String tid, int page, String pid, PostRateLog log) {
    final key = (tid, page);
    final cached = _pages[key];
    if (cached == null) return;
    _pages[key] = _RateLogPageCache(
      {...cached.logs, pid: log},
      DateTime.now(),
    );
  }

  static void clearTid(String tid) {
    _pages.removeWhere((key, _) => key.$1 == tid);
  }

  @visibleForTesting
  static void clearAll() => _pages.clear();
}

class ThreadRateLogsNotifier extends Notifier<Map<String, PostRateLog>> {
  ThreadRateLogsNotifier(this.tid);

  final String tid;
  int? _loadedPage;
  final Map<int, Future<void>> _inFlightPages = {};

  @override
  Map<String, PostRateLog> build() => const {};

  void clear() {
    _loadedPage = null;
    _inFlightPages.clear();
    _RateLogSessionStore.clearTid(tid);
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
    if (!force) {
      final cached = _RateLogSessionStore.get(tid, page);
      if (cached != null) {
        _loadedPage = page;
        mergePage(cached);
        return Future.value();
      }
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
    // 即使 provider 已 dispose，仍写入会话缓存，避免返回同页重复拉 HTML。
    _RateLogSessionStore.put(tid, page, rateLogs);
    if (!ref.mounted) return;
    mergePage(rateLogs);
    _loadedPage = page;
  }

  Future<void> loadFullRateLog(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    final full = await service.fetchFullRateLog(tid, pid);
    if (!ref.mounted || full == null) return;
    setForPid(pid, full);
    final page = _loadedPage;
    if (page != null) {
      _RateLogSessionStore.updatePid(tid, page, pid, full);
    }
  }
}

class _RateLogPageCache {
  const _RateLogPageCache(this.logs, this.loadedAt);

  final Map<String, PostRateLog> logs;
  final DateTime loadedAt;
}

final threadRateLogsProvider = NotifierProvider.autoDispose
    .family<ThreadRateLogsNotifier, Map<String, PostRateLog>, String>(
  ThreadRateLogsNotifier.new,
);

/// Test helper: clear process-wide rate-log session cache.
@visibleForTesting
void clearRateLogSessionCacheForTest() => _RateLogSessionStore.clearAll();

/// 按 (tid, pid) 订阅单条评分日志。
final rateLogProvider = Provider.autoDispose.family<PostRateLog?, RateLogKey>(
  (ref, key) {
    final (tid, pid) = key;
    return ref.watch(threadRateLogsProvider(tid).select((logs) => logs[pid]));
  },
);
