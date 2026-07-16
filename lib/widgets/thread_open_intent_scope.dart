import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thread_open_intent.dart';
import '../providers/thread_open_intent_provider.dart';

/// 为单个帖子详情提供路由打开意图。
///
/// Key 必须随 [tid] 变化，避免 Riverpod 在同一个 ProviderScope 上把一个
/// family provider 的 override 原地替换成另一个 family provider。
class ThreadOpenIntentScope extends StatelessWidget {
  const ThreadOpenIntentScope({
    super.key,
    required this.tid,
    required this.intent,
    required this.child,
  });

  final String tid;
  final ThreadOpenIntent? intent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('thread-open-intent-$tid'),
      overrides: [
        threadOpenIntentProvider(tid).overrideWithValue(intent),
      ],
      child: child,
    );
  }
}
