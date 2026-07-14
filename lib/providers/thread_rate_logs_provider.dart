import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rate_log.dart';
import 'post_provider.dart';

typedef RateLogKey = (String tid, String pid);

class ThreadRateLogsNotifier extends Notifier<Map<String, PostRateLog>> {
  ThreadRateLogsNotifier(this.tid);

  final String tid;
  int? _loadedPage;
  bool _loading = false;

  @override
  Map<String, PostRateLog> build() => const {};

  void clear() {
    _loadedPage = null;
    _loading = false;
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

  Future<void> ensurePageRateLogs(int page) async {
    if (_loadedPage == page || _loading) return;
    _loading = true;
    try {
      final service = ref.read(rateLogServiceProvider);
      final rateLogs = await service.fetchRateLogs(tid, page: page);
      if (!ref.mounted) return;
      replacePage(rateLogs);
      _loadedPage = page;
    } finally {
      _loading = false;
    }
  }

  Future<void> loadFullRateLog(String pid) async {
    final service = ref.read(rateLogServiceProvider);
    final full = await service.fetchFullRateLog(tid, pid);
    if (!ref.mounted || full == null) return;
    setForPid(pid, full);
  }
}

final threadRateLogsProvider = NotifierProvider.family<ThreadRateLogsNotifier,
    Map<String, PostRateLog>, String>(
  ThreadRateLogsNotifier.new,
);

/// 按 (tid, pid) 订阅单条评分日志。
final rateLogProvider = Provider.autoDispose.family<PostRateLog?, RateLogKey>(
  (ref, key) {
    final (tid, pid) = key;
    return ref.watch(threadRateLogsProvider(tid).select((logs) => logs[pid]));
  },
);
