/// 末端越界刷新武装：第一次只记触底，松手后再越界才允许刷新。
///
/// 用来避免同一手势里的回弹 / 惯性 overscroll 误触发网络请求。
class TerminalRefreshArming {
  bool _refreshDispatchedThisGesture = false;
  bool _sawTerminalThisGesture = false;
  bool _endedSinceTerminalHit = false;

  void onScrollEnd() {
    _refreshDispatchedThisGesture = false;
    if (_sawTerminalThisGesture) {
      _endedSinceTerminalHit = true;
    }
    _sawTerminalThisGesture = false;
  }

  /// 一次末端越界。返回是否应触发刷新。
  bool shouldRefresh({required bool repeating}) {
    _sawTerminalThisGesture = true;
    if (repeating &&
        _endedSinceTerminalHit &&
        !_refreshDispatchedThisGesture) {
      _refreshDispatchedThisGesture = true;
      _endedSinceTerminalHit = false;
      return true;
    }
    if (!repeating) {
      _endedSinceTerminalHit = false;
    }
    return false;
  }

  void reset() {
    _refreshDispatchedThisGesture = false;
    _sawTerminalThisGesture = false;
    _endedSinceTerminalHit = false;
  }
}
