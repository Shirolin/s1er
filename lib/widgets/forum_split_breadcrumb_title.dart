import 'package:flutter/material.dart';

import 's1_adaptive_sheet.dart';
import 's1_click_region.dart';

void showThreadFullTitleSheet(BuildContext context, String title) {
  showS1InfoSheet<void>(
    context: context,
    builder: (context) => S1AdaptiveSheetScaffold(
      children: [
        Text(
          '完整标题',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class ForumSplitBreadcrumbTitle extends StatelessWidget {
  const ForumSplitBreadcrumbTitle({
    super.key,
    required this.forumLabel,
    required this.threadTitle,
    required this.onForumTap,
    this.onThreadTap,
    this.loading = false,
    this.floorContext,
  });

  final String forumLabel;
  final String? threadTitle;
  final VoidCallback onForumTap;
  final VoidCallback? onThreadTap;
  final bool loading;

  /// Optional second line (e.g. floor page context in split view).
  final String? floorContext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final forumStyle = textTheme.titleLarge?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    );
    final separatorStyle = textTheme.titleLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final threadStyle = textTheme.titleLarge;

    if (loading) {
      return Text('加载中…', style: threadStyle);
    }

    final title = threadTitle;
    final breadcrumb = title == null || title.isEmpty
        ? S1ClickRegion(
            onTap: onForumTap,
            child: Text(forumLabel, style: forumStyle, maxLines: 1),
          )
        : Row(
            children: [
              Flexible(
                child: S1ClickRegion(
                  onTap: onForumTap,
                  child: Text(
                    forumLabel,
                    style: forumStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('›', style: separatorStyle),
              ),
              Flexible(
                flex: 2,
                child: Tooltip(
                  message: title,
                  child: S1ClickRegion(
                    onTap: onThreadTap,
                    child: Text(
                      title,
                      style: threadStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          );

    final floor = floorContext;
    if (floor == null || floor.isEmpty) {
      return breadcrumb;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        breadcrumb,
        Text(
          floor,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
