import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/rate_log.dart';
import '../services/talker.dart';
import 'post_provider.dart';

typedef RateLogKey = (String tid, String pid);

/// 进程内会话缓存：按 (tid, pid) 存放解析结果，含「已确认无评分」的空条目，
/// 避免标记命中但无评分的楼层被反复请求。
///
/// 不依赖 keepAlive Timer，避免 widget 测试残留定时器。
class _RateLogSessionStore {
  _RateLogSessionStore._();

  static final Map<(String tid, String pid), _CachedRateLog> _logs = {};

  /// 返回缓存条目；`log == null` 表示已确认该楼没有评分。
  static _CachedRateLog? get(String tid, String pid) {
    final key = (tid, pid);
    final cached = _logs[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.loadedAt) >=
        S1Constants.postSessionCacheExpiry) {
      _logs.remove(key);
      return null;
    }
    return cached;
  }

  static void putLog(String tid, String pid, PostRateLog log) {
    _logs[(tid, pid)] = _CachedRateLog(log, DateTime.now());
  }

  static void putEmpty(String tid, String pid) {
    _logs[(tid, pid)] = _CachedRateLog(null, DateTime.now());
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
  final Set<String> _markedPids = {};

  @override
  Map<String, PostRateLog> build() => const {};

  void clear() {
    _inFlightPids.clear();
    _markedPids.clear();
    _RateLogSessionStore.clearTid(tid);
    state = const {};
  }

  void setForPid(String pid, PostRateLog log) {
    state = {...state, pid: log};
  }

  /// 登记本页 v4 `Variables.commentcount` 标记出的 pid。
  ///
  /// 只登记不请求；真正拉取由可见楼层的 `_PostRateLogSection` 触发，
  /// 避免翻页时对本页所有标记楼批量发请求。
  void markPids(Iterable<String> pids) {
    _markedPids.addAll(pids.where((pid) => pid.isNotEmpty));
  }

  bool isMarked(String pid) => _markedPids.contains(pid);

  /// 拉取单楼评分记录（先查会话缓存）。
  ///
  /// 与 `S1HttpClient` 的全局限速叠加；同一 pid 的并发调用复用同一 future。
  Future<void> ensureRateLog(String pid) async {
    if (pid.isEmpty) return;

    final cached = _RateLogSessionStore.get(tid, pid);
    if (cached != null) {
      final log = cached.log;
      if (log != null && ref.mounted && state[pid] == null) {
        setForPid(pid, log);
      }
      return;
    }

    await _ensurePid(pid);
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

  /// 强制刷新单楼（评分提交后使用），不复用缓存与在途请求。
  Future<void> refreshRateLog(String pid) => _fetchPid(pid);

  Future<void> _fetchPid(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    try {
      final log = await service.fetchRateLog(tid, pid);
      if (log == null) {
        _RateLogSessionStore.putEmpty(tid, pid);
        return;
      }
      _RateLogSessionStore.putLog(tid, pid, log);
      if (!ref.mounted) return;
      setForPid(pid, log);
    } catch (e, st) {
      // 请求失败不写缓存，保留下次重试机会。
      talker.handle(e, st, 'fetch rate log failed tid=$tid pid=$pid');
    }
  }
}

class _CachedRateLog {
  const _CachedRateLog(this.log, this.loadedAt);

  /// null 表示已确认该楼没有评分。
  final PostRateLog? log;
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
