import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/window_size.dart';
import 's1_adaptive_sheet.dart';

typedef PageItemLabelBuilder = String Function(int page);

/// 打开页码选择 BottomSheet。
///
/// [currentPage] 为 null 时不高亮当前页（用于列表入口跳转）。
Future<void> showPagePickerSheet({
  required BuildContext context,
  required int totalPages,
  required ValueChanged<int> onPageSelected,
  int? currentPage,
  String title = '选择页码',
  String? subtitle,
  PageItemLabelBuilder? pageItemLabelBuilder,
}) {
  return showS1AdaptiveSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => PagePickerSheet(
      totalPages: totalPages,
      currentPage: currentPage,
      title: title,
      subtitle: subtitle,
      pageItemLabelBuilder: pageItemLabelBuilder,
      onPageSelected: (page) {
        Navigator.pop(ctx);
        onPageSelected(page);
      },
    ),
  );
}

class PagePickerSheet extends StatefulWidget {
  const PagePickerSheet({
    super.key,
    required this.totalPages,
    required this.onPageSelected,
    this.currentPage,
    this.title = '选择页码',
    this.subtitle,
    this.pageItemLabelBuilder,
  });

  final int totalPages;
  final int? currentPage;
  final String title;
  final String? subtitle;
  final PageItemLabelBuilder? pageItemLabelBuilder;
  final ValueChanged<int> onPageSelected;

  @override
  State<PagePickerSheet> createState() => _PagePickerSheetState();
}

class _PagePickerSheetState extends State<PagePickerSheet> {
  final _jumpController = TextEditingController();
  String? _jumpError;

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }

  void _submitJump() {
    final page = int.tryParse(_jumpController.text.trim());
    if (page == null || page < 1 || page > widget.totalPages) {
      setState(() {
        _jumpError = '请输入 1 - ${widget.totalPages} 之间的页码';
      });
      return;
    }
    widget.onPageSelected(page);
  }

  List<int> _visiblePages({required int radius}) {
    final total = widget.totalPages;
    if (total <= 50) {
      return List<int>.generate(total, (i) => i + 1);
    }

    final anchor = widget.currentPage ?? 1;
    final pages = <int>{1, total, anchor};
    for (var i = anchor - radius; i <= anchor + radius; i++) {
      if (i >= 1 && i <= total) pages.add(i);
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  List<int?> _pageEntries(List<int> pages) {
    final entries = <int?>[];
    for (var index = 0; index < pages.length; index++) {
      if (index > 0 && pages[index] - pages[index - 1] > 1) {
        entries.add(null);
      }
      entries.add(pages[index]);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = context.isExpandedOrAbove;
    final pages = _visiblePages(radius: isDesktop ? 2 : 5);
    final pageEntries = _pageEntries(pages);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                isDesktop ? 24 : 0,
                24,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.title,
                        style: (isDesktop
                                ? textTheme.titleMedium
                                : textTheme.titleLarge)
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: S1Shape.medium,
                        ),
                        child: Text(
                          '共 ${widget.totalPages} 页',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jumpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '输入页码 (1 - ${widget.totalPages})',
                        errorText: _jumpError,
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: S1Shape.medium,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: S1Shape.medium,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: scheme.primary, width: 2),
                          borderRadius: S1Shape.medium,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: scheme.error),
                          borderRadius: S1Shape.medium,
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: scheme.error, width: 2),
                          borderRadius: S1Shape.medium,
                        ),
                      ),
                      onSubmitted: (_) => _submitJump(),
                      onChanged: (_) {
                        if (_jumpError != null) {
                          setState(() => _jumpError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: S1BottomBarStyle.minTouchTarget,
                    child: FilledButton(
                      onPressed: _submitJump,
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: S1Shape.medium,
                        ),
                      ),
                      child: const Text('跳转'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            Flexible(
              child: ClipRect(
                child: isDesktop
                    ? GridView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 56,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: pageEntries.length,
                        itemBuilder: (context, index) => _PageEntryTile(
                          page: pageEntries[index],
                          currentPage: widget.currentPage,
                          labelBuilder: widget.pageItemLabelBuilder,
                          onSelected: widget.onPageSelected,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: pageEntries.length,
                        itemBuilder: (context, index) => _PageEntryTile(
                          page: pageEntries[index],
                          currentPage: widget.currentPage,
                          labelBuilder: widget.pageItemLabelBuilder,
                          onSelected: widget.onPageSelected,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageEntryTile extends StatelessWidget {
  const _PageEntryTile({
    required this.page,
    required this.currentPage,
    required this.labelBuilder,
    required this.onSelected,
  });

  final int? page;
  final int? currentPage;
  final PageItemLabelBuilder? labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final page = this.page;
    if (page == null) {
      return Center(
        child: Icon(
          Icons.more_horiz,
          size: 18,
          color: scheme.outline,
        ),
      );
    }

    final isCurrent = currentPage != null && page == currentPage;
    return ListTile(
      shape: const RoundedRectangleBorder(borderRadius: S1Shape.medium),
      selected: isCurrent,
      selectedTileColor:
          scheme.primaryContainer.withValues(alpha: S1Alpha.half),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isCurrent ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: S1Shape.large,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '$page',
            style: textTheme.bodyMedium?.copyWith(
              color: isCurrent ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        labelBuilder?.call(page) ?? '第 $page 页',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.titleSmall?.copyWith(
          color: isCurrent ? scheme.primary : scheme.onSurface,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: isCurrent
          ? Icon(Icons.check_circle, color: scheme.primary, size: 22)
          : Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant.withValues(alpha: S1Alpha.strong),
              size: 18,
            ),
      onTap: isCurrent
          ? null
          : () {
              S1Haptics.selection();
              onSelected(page);
            },
    );
  }
}
