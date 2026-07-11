import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import 'page_picker_sheet.dart';

export 'page_picker_sheet.dart' show PageItemLabelBuilder, showPagePickerSheet;

typedef PageChangeCallback = Future<void> Function(int page);

/// M3 底部分页栏：上一页 / 下一页 + 可点击页码指示器。
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

  List<Widget> _controls({
    required bool showEdgeButtons,
    required bool canPrev,
    required bool canNext,
    required int page,
    required int total,
    required TextTheme textTheme,
    required ColorScheme scheme,
  }) {
    return [
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
    ];
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

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: S1BottomBarStyle.decoration(scheme),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading)
                LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: scheme.surfaceContainer,
                  color: scheme.primary,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: S1BottomBarStyle.barVerticalPadding,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final controls = _controls(
                      showEdgeButtons: showEdgeButtons,
                      canPrev: canPrev,
                      canNext: canNext,
                      page: page,
                      total: total,
                      textTheme: textTheme,
                      scheme: scheme,
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: controls,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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

    return Semantics(
      button: true,
      enabled: enabled,
      label: '第 $currentPage / $totalPages 页，选择页码',
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: S1Shape.full,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: S1Shape.full,
          child: SizedBox(
            height: S1BottomBarStyle.minTouchTarget,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompactLabel.text(
                    '第 $currentPage / $totalPages 页',
                    style: labelStyle,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 24,
                    color: enabled
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface.withValues(alpha: S1Alpha.disabledIcon),
                  ),
                ],
              ),
            ),
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
      icon: Icon(icon),
      style: IconButton.styleFrom(
        iconSize: 24,
        minimumSize: const Size(
          S1BottomBarStyle.minTouchTarget,
          S1BottomBarStyle.minTouchTarget,
        ),
        foregroundColor: scheme.onSurfaceVariant,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: S1Alpha.disabledIcon),
      ),
    );
  }
}
