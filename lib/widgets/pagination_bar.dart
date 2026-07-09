import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import 'page_picker_sheet.dart';

export 'page_picker_sheet.dart' show PageItemLabelBuilder, showPagePickerSheet;

typedef PageChangeCallback = Future<void> Function(int page);

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
    showPagePickerSheet(
      context: context,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
      title: widget.sheetTitle,
      subtitle: widget.sheetSubtitle,
      pageItemLabelBuilder: widget.pageItemLabelBuilder,
      onPageSelected: _goTo,
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
