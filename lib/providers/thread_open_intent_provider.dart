import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thread_open_intent.dart';

/// 帖子详情首屏打开意图；由 [`app.dart`] 路由 builder 通过 `ProviderScope` 注入。
final threadOpenIntentProvider =
    Provider.autoDispose.family<ThreadOpenIntent?, String>(
  (ref, tid) => null,
  dependencies: const [],
);
