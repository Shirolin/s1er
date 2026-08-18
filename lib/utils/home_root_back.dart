/// 首页根路由上的系统返回：先回论坛 Tab，论坛上再确认才退出。
enum HomeRootBackAction {
  /// 当前不是论坛 Tab，切回论坛。
  goForum,

  /// 已在论坛：提示「再返回一次」并开始退出窗口。
  armExit,

  /// 退出窗口内再次返回，可以退出应用。
  exit,

  /// 已在论坛但不在可退出平台（非 Android），吞掉返回。
  ignore,
}

/// 首页根返回的时间窗口与提示文案。
abstract class HomeRootBack {
  static const window = Duration(seconds: 2);
  static const snackMessage = '再返回一次退出应用';
}

/// 判定首页根（无子路由可 pop）时系统返回该做什么。
HomeRootBackAction resolveHomeRootBack({
  required bool isForumTab,
  required DateTime now,
  DateTime? lastExitArmedAt,
  required bool canExitApp,
  Duration window = HomeRootBack.window,
}) {
  if (!isForumTab) return HomeRootBackAction.goForum;
  if (!canExitApp) return HomeRootBackAction.ignore;
  if (lastExitArmedAt != null && now.difference(lastExitArmedAt) <= window) {
    return HomeRootBackAction.exit;
  }
  return HomeRootBackAction.armExit;
}
