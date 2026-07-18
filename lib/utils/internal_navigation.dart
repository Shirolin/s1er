import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../widgets/in_thread_jump_capture.dart';

/// 打开站内路由（帖链 / 引用跳转）。
///
/// 已在同一 `/thread/:tid` 上时用 [GoRouter.replace]，就地更新 query/intent，
/// 避免再 `push` 一层同帖（共享 [postProvider] 时叠两层会互相踩状态）。
/// 返回上一阅读位置由 [ThreadDetailScreen] 的页内跳转栈拦截 Back 处理；
/// 抓拍必须在 `replace` 之前完成（replace 可能导致详情 State remount）。
void openInternalLocation(BuildContext context, String location) {
  final target = Uri.parse(location);
  final current = GoRouterState.of(context).uri;
  if (_sameThreadPath(current, target)) {
    InThreadJumpCapture.captureIfPresent(context);
    context.replace(location);
    return;
  }
  context.push(location);
}

bool _sameThreadPath(Uri current, Uri target) {
  final currentTid = _threadTid(current);
  final targetTid = _threadTid(target);
  return currentTid != null && currentTid == targetTid;
}

String? _threadTid(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments[0] == 'thread') {
    final tid = segments[1];
    return tid.isEmpty ? null : tid;
  }
  return null;
}
