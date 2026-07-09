import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/compact_label.dart';

typedef PageChangeCallback = Future<void> Function(int page);
typedef PageItemLabelBuilder = String Function(int page);

/// M3 底部分页栏：上一页 / 下一页 + 可点击页码指示器。
///
/// 相比原 ActionChip + AlertDialog 方案：
/// - 窄屏仅保留核心翻页，宽屏显示首页/末页
/// - 页码选择使用 BottomSheet（与主题卡片页码选择一致）
/// - 禁用态、加载态符合 M3 语义色
class PaginationBar extends StatefulWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.sheetTitle = '选择页码',
    this.sheetSubtitle,
    this.pageItemLabelBuilder,
  });

  final int currentPage;
  final int totalPages;
  final PageChangeCallback onPageChanged;
  final String sheetTitle;
  final String? sheetSubtitle;
  final PageItemLabelBuilder? pageItemLabelBuilder;

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  bool _isLoading = false;

  Future<void> _goTo(int page) async {
    if (_isLoading || page == widget.currentPage) return;
    if (page < 1 || page > widget.totalPages) return;

    setState(() => _isLoading = true);
    try {
      await widget.onPageChanged(page);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPagePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _PagePickerSheet(
        currentPage: widget.currentPage,
        totalPages: widget.totalPages,
        title: widget.sheetTitle,
        subtitle: widget.sheetSubtitle,
        pageItemLabelBuilder: widget.pageItemLabelBuilder,
        onPageSelected: (page) {
          Navigator.pop(ctx);
          _goTo(page);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalPages <= 1) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final page = widget.currentPage;
    final total = widget.totalPages;
    final canPrev = page > 1 && !_isLoading;
    final canNext = page < total && !_isLoading;
    final showEdgeButtons = MediaQuery.sizeOf(context).width >= 400;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: scheme.surfaceContainer,
                color: scheme.primary,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showEdgeButtons) ...[
                    _PaginationIconButton(
                      icon: Icons.first_page,
                      tooltip: '首页',
                      enabled: canPrev,
                      onPressed: () => _goTo(1),
                    ),
                  ],
                  _PaginationIconButton(
                    icon: Icons.chevron_left,
                    tooltip: '上一页',
                    enabled: canPrev,
                    onPressed: () => _goTo(page - 1),
                  ),
                  const SizedBox(width: 8),
                  _PageIndicator(
                    currentPage: page,
                    totalPages: total,
                    enabled: !_isLoading,
                    onTap: _showPagePicker,
                    textTheme: textTheme,
                    scheme: scheme,
                  ),
                  const SizedBox(width: 8),
                  _PaginationIconButton(
                    icon: Icons.chevron_right,
                    tooltip: '下一页',
                    enabled: canNext,
                    onPressed: () => _goTo(page + 1),
                  ),
                  if (showEdgeButtons) ...[
                    _PaginationIconButton(
                      icon: Icons.last_page,
                      tooltip: '末页',
                      enabled: canNext,
                      onPressed: () => _goTo(total),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
    required this.enabled,
    required this.onTap,
    required this.textTheme,
    required this.scheme,
  });

  final int currentPage;
  final int totalPages;
  final bool enabled;
  final VoidCallback onTap;
  final TextTheme textTheme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = CompactLabel.style(
      context,
      base: textTheme.labelLarge,
      color: scheme.onSecondaryContainer,
      fontWeight: FontWeight.w600,
    );

    return Material(
      color: scheme.secondaryContainer,
      borderRadius: S1Shape.full,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: S1Shape.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompactLabel.text(
                '第 $currentPage / $totalPages 页',
                style: labelStyle,
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more,
                size: 18,
                color: enabled
                    ? scheme.onSecondaryContainer
                    : scheme.onSurface.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationIconButton extends StatelessWidget {
  const _PaginationIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }
}

class _PagePickerSheet extends StatefulWidget {
  const _PagePickerSheet({
    required this.currentPage,
    required this.totalPages,
    required this.title,
    required this.onPageSelected,
    this.subtitle,
    this.pageItemLabelBuilder,
  });

  final int currentPage;
  final int totalPages;
  final String title;
  final String? subtitle;
  final PageItemLabelBuilder? pageItemLabelBuilder;
  final ValueChanged<int> onPageSelected;

  @override
  State<_PagePickerSheet> createState() => _PagePickerSheetState();
}

class _PagePickerSheetState extends State<_PagePickerSheet> {
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

  List<int> _visiblePages() {
    final total = widget.totalPages;
    if (total <= 50) {
      return List<int>.generate(total, (i) => i + 1);
    }

    final current = widget.currentPage;
    final pages = <int>{1, total, current};
    for (var i = current - 5; i <= current + 5; i++) {
      if (i >= 1 && i <= total) pages.add(i);
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pages = _visiblePages();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: textTheme.titleMedium),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
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
                  Text(
                    '共 ${widget.totalPages} 页',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jumpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '输入页码',
                        errorText: _jumpError,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submitJump(),
                      onChanged: (_) {
                        if (_jumpError != null) {
                          setState(() => _jumpError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _submitJump,
                    child: const Text('跳转'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: pages.length,
                itemBuilder: (ctx, index) {
                  final page = pages[index];
                  final isCurrent = page == widget.currentPage;
                  final showEllipsisBefore = index > 0 && page - pages[index - 1] > 1;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showEllipsisBefore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '…',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: S1Shape.small,
                        ),
                        selected: isCurrent,
                        selectedTileColor: scheme.secondaryContainer,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isCurrent
                              ? scheme.primary
                              : scheme.primaryContainer,
                          child: Text(
                            '$page',
                            style: textTheme.labelSmall?.copyWith(
                              color: isCurrent
                                  ? scheme.onPrimary
                                  : scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          widget.pageItemLabelBuilder?.call(page) ??
                              '第 $page 页',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isCurrent ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(Icons.check, color: scheme.primary, size: 20)
                            : Icon(
                                Icons.chevron_right,
                                color: scheme.onSurfaceVariant,
                                size: 18,
                              ),
                        onTap: isCurrent ? null : () => widget.onPageSelected(page),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
