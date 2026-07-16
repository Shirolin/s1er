import 'window_size.dart';

/// 大屏论坛列表是否应在当前路由内打开帖子。
bool shouldOpenForumThreadInPlace(double windowWidth) =>
    windowWidth.toWindowSize().index >= S1WindowSize.large.index;

/// 大屏论坛是否应显示列表与详情双栏。
bool shouldShowForumSplitView(
  double windowWidth, {
  required bool hasSelectedThread,
}) =>
    shouldOpenForumThreadInPlace(windowWidth) && hasSelectedThread;
