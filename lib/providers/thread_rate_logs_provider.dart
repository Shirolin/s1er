import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/rate_log.dart';
import '../services/http_client.dart';
import '../services/rate_log_service.dart';
import '../services/talker.dart';

typedef RateLogKey = (String tid, String pid);

final rateLogServiceProvider = Provider<RateLogService>((ref) {
  return RateLogService(ref.watch(httpClientProvider));
});

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
  final Map<String, Future<bool>> _inFlightPids = {};
  final Set<String> _markedPids = {};

  @override
  Map<String, PostRateLog> build() => const {};

  void clear() {
    _inFlightPids.clear();
    _markedPids.clear();
    _RateLogSessionStore.clearTid(tid);
    state = const {};
  }

  /// 登记本页 v4 `Variables.commentcount` 标记出的 pid。
  ///
  /// 只登记不请求；真正拉取由可见楼层的 `_PostRateLogSection` 触发，
  /// 避免翻页时对本页所有标记楼批量发请求。
  void markPids(Iterable<String> pids) {
    _markedPids.addAll(pids.where((pid) => pid.isNotEmpty));
  }

  /// 直接写入已解析好的评分记录（整页 HTML 兜底用），并登记标记。
  void primeRateLog(String pid, PostRateLog log) {
    if (pid.isEmpty) return;
    _markedPids.add(pid);
    _RateLogSessionStore.putLog(tid, pid, log);
    if (ref.mounted) _setForPid(pid, log);
  }

  bool isMarked(String pid) => _markedPids.contains(pid);

  /// 拉取单楼评分记录（先查会话缓存）。
  ///
  /// 返回 true 表示已得到结果（有评分或无评分），false 表示请求失败
  /// （不写缓存，调用方可提示重试）。同一 pid 的并发调用复用同一 future。
  Future<bool> ensureRateLog(String pid) async {
    if (pid.isEmpty) return true;

    final cached = _RateLogSessionStore.get(tid, pid);
    if (cached != null) {
      final log = cached.log;
      if (log != null && ref.mounted && state[pid] == null) {
        _setForPid(pid, log);
      }
      return true;
    }

    return _ensurePid(pid);
  }

  Future<bool> _ensurePid(String pid) {
    final inFlight = _inFlightPids[pid];
    if (inFlight != null) return inFlight;

    late final Future<bool> future;
    future = _fetchPid(pid).whenComplete(() {
      _inFlightPids.remove(pid);
    });
    _inFlightPids[pid] = future;
    return future;
  }

  /// 强制刷新单楼（评分提交后使用），不复用缓存与在途请求。
  Future<bool> refreshRateLog(String pid) => _fetchPid(pid);

  Future<bool> _fetchPid(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    try {
      final log = await service.fetchRateLog(tid, pid);
      if (log == null) {
        _RateLogSessionStore.putEmpty(tid, pid);
        if (ref.mounted) _removePid(pid);
        return true;
      }
      _RateLogSessionStore.putLog(tid, pid, log);
      if (ref.mounted) _setForPid(pid, log);
      return true;
    } catch (e, st) {
      // 请求/解析失败不写缓存，保留下次重试机会。
      talker.handle(e, st, 'fetch rate log failed tid=$tid pid=$pid');
      return false;
    }
  }

  void _setForPid(String pid, PostRateLog log) {
    state = {...state, pid: log};
  }

  void _removePid(String pid) {
    if (!state.containsKey(pid)) return;
    state = {...state}..remove(pid);
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
