import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/rate_log.dart';
import 'post_provider.dart';

typedef RateLogKey = (String tid, String pid);

/// 进程内会话缓存：按 (tid, pid) 存放已拉到的评分记录，
/// 不依赖 keepAlive Timer，避免 widget 测试残留定时器。
class _RateLogSessionStore {
  _RateLogSessionStore._();

  static final Map<(String tid, String pid), _CachedRateLog> _logs = {};

  static PostRateLog? get(String tid, String pid) {
    final key = (tid, pid);
    final cached = _logs[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.loadedAt) >=
        S1Constants.postSessionCacheExpiry) {
      _logs.remove(key);
      return null;
    }
    return cached.log;
  }

  static void put(String tid, String pid, PostRateLog log) {
    _logs[(tid, pid)] = _CachedRateLog(log, DateTime.now());
  }

  static void clearTid(String tid) {
    _logs.removeWhere((key, _) => key.$1 == tid);
  }

  @visibleForTesting
  static void clearAll() => _logs.clear();
}

class ThreadRateLogsNotifier extends Notifier<Map<String, PostRateLog>> {
  ThreadRateLogsNotifier(this.tid);

  final String tid;
  final Map<String, Future<void>> _inFlightPids = {};

  @override
  Map<String, PostRateLog> build() => const {};

  void clear() {
    _inFlightPids.clear();
    _RateLogSessionStore.clearTid(tid);
    state = const {};
  }

  void mergeLogs(Map<String, PostRateLog> rateLogs) {
    if (rateLogs.isEmpty) return;
    state = {...state, ...rateLogs};
  }

  void setForPid(String pid, PostRateLog log) {
    state = {...state, pid: log};
  }

  /// 按 v4 `commentcount` 标记出的 pid 逐个补拉评分记录。
  ///
  /// 已缓存（会话内 2 分钟）或正在请求的 pid 不会重复发请求；串行执行，
  /// 与 `S1HttpClient` 的全局限速叠加，避免翻页时放大请求。
  Future<void> ensureRateLogs(Iterable<String> pids) async {
    for (final pid in pids.toSet()) {
      if (pid.isEmpty) continue;
      final cached = _RateLogSessionStore.get(tid, pid);
      if (cached != null) {
        if (ref.mounted && state[pid] == null) setForPid(pid, cached);
        continue;
      }
      await _ensurePid(pid);
    }
  }

  Future<void> _ensurePid(String pid) {
    final inFlight = _inFlightPids[pid];
    if (inFlight != null) return inFlight;

    late final Future<void> future;
    future = _fetchPid(pid).whenComplete(() {
      _inFlightPids.remove(pid);
    });
    _inFlightPids[pid] = future;
    return future;
  }

  Future<void> _fetchPid(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    final log = await service.fetchFullRateLog(tid, pid);
    // 无评分或请求失败不写缓存，便于下次进入重试。
    if (log == null) return;
    _RateLogSessionStore.put(tid, pid, log);
    if (!ref.mounted) return;
    setForPid(pid, log);
  }

  Future<void> loadFullRateLog(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    final full = await service.fetchFullRateLog(tid, pid);
    if (full == null) return;
    _RateLogSessionStore.put(tid, pid, full);
    if (!ref.mounted) return;
    setForPid(pid, full);
  }
}

class _CachedRateLog {
  const _CachedRateLog(this.log, this.loadedAt);

  final PostRateLog log;
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
