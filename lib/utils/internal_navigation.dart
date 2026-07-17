import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 打开站内路由（帖链 / 引用跳转）。
///
/// 已在同一 `/thread/:tid` 上时用 [GoRouter.replace]，就地更新 query/intent，
/// 避免再 `push` 一张同 tid 页（自定义稳定 Page key 时会触发 Navigator 重复 key 断言；
/// 即使用 `state.pageKey` 也会无意义叠两层同帖）。
void openInternalLocation(BuildContext context, String location) {
  final target = Uri.parse(location);
  final current = GoRouterState.of(context).uri;
  if (_sameThreadPath(current, target)) {
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
