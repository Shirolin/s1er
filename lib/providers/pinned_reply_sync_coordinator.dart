import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pinned_threads_provider.dart';

/// 冷启动后延迟慢速同步置顶帖回复数（限流 + 单帖 CD）。
final pinnedReplySyncCoordinatorProvider = Provider<void>((ref) {
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    unawaited(
      ref.read(pinnedThreadsProvider.notifier).syncAllStaleReplyCounts(),
    );
  });
});
