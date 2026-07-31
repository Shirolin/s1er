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

/// Minimum list pane width when user-resized (desktop split).
const double forumListPaneMinWidth = 360;

/// Maximum list pane width when user-resized (desktop split).
const double forumListPaneMaxWidth = 600;

/// List-detail 模式下的列表栏宽度：随可用空间增长，但避免过窄或挤占正文。
///
/// [userOverride] persists a user drag-resize; clamped to
/// [forumListPaneMinWidth]..min([forumListPaneMaxWidth], available * 0.5).
double forumListPaneWidth(
  double availableWidth, {
  double? userOverride,
}) {
  if (userOverride != null) {
    final maxAllowed = (availableWidth * 0.5)
        .clamp(forumListPaneMinWidth, forumListPaneMaxWidth)
        .toDouble();
    return userOverride.clamp(forumListPaneMinWidth, maxAllowed);
  }
  return (availableWidth * 0.38).clamp(420.0, 520.0);
}
