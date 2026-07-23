import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// M3 菜单规格常量（[MenuAnchor] / [MenuItemButton]）。
abstract class S1MenuSpec {
  static const double iconSize = 24;
  static const double itemHorizontalPadding = 12;
  static const double dividerVerticalGap = 8;
  /// Wide enough for leading icon + short CJK label + trailing check.
  static const double minWidth = 200;
  static const double maxWidth = 280;
  static const double underAnchorGap = 4;

  /// 顶层菜单与窗口边缘的最小间距（[MenuAnchor.reservedPadding]）。
  static const double screenEdgePadding = 24;

  /// [MenuAnchor] 在 LTR + [AlignmentDirectional.topEnd] 下默认向右展开；
  /// 左移 [minWidth]，使菜单大致与 ⋮ 右缘对齐。实际更宽时由
  /// [reservedPadding] 在贴边时把整块菜单收回安全区。
  static Offset underAnchorOffset(BuildContext context) {
    final textDirection = Directionality.of(context);
    final dx = textDirection == TextDirection.rtl ? minWidth : -minWidth;
    return Offset(dx, underAnchorGap);
  }

  static EdgeInsets get reservedPadding => const EdgeInsets.fromLTRB(
        screenEdgePadding,
        8,
        screenEdgePadding,
        8,
      );

  static MenuStyle anchoredMenuStyle(BuildContext context) {
    final base = MenuTheme.of(context).style ?? const MenuStyle();
    return base.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(minWidth, 0)),
      maximumSize:
          const WidgetStatePropertyAll(Size(maxWidth, double.infinity)),
      fixedSize: const WidgetStatePropertyAll(Size.fromWidth(minWidth)),
      alignment: AlignmentDirectional.topEnd,
    );
  }
}

/// M3 内缩分隔线：左右 12dp、上下各 8dp 留白。
class S1MenuDivider extends StatelessWidget {
  const S1MenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        S1MenuSpec.itemHorizontalPadding,
        S1MenuSpec.dividerVerticalGap,
        S1MenuSpec.itemHorizontalPadding,
        S1MenuSpec.dividerVerticalGap,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// M3 菜单项：48dp 高度、24dp 图标、语义色、labelLarge 排版。
///
/// When [selected] is true, shows a trailing check while keeping [icon] as the
/// leading affordance (single-select menu pattern).
Widget s1MenuItem({
  required VoidCallback? onPressed,
  required IconData icon,
  required String label,
  bool destructive = false,
  bool selected = false,
}) {
  return Builder(
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      ButtonStyle? style;
      if (destructive) {
        style = ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: S1Alpha.disabledIcon);
            }
            return scheme.error;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: S1Alpha.disabledIcon);
            }
            return scheme.error;
          }),
        );
      }

      return MenuItemButton(
        onPressed: onPressed,
        leadingIcon: Icon(icon, size: S1MenuSpec.iconSize),
        trailingIcon: selected
            ? const Icon(Icons.check, size: S1MenuSpec.iconSize)
            : null,
        style: style,
        child: Text(label),
      );
    },
  );
}

/// ⋮ 触发的 M3 [MenuAnchor]：菜单在锚点下方、右对齐弹出。
class S1IconMenuAnchor extends StatelessWidget {
  const S1IconMenuAnchor({
    super.key,
    required this.menuChildren,
    this.tooltip = '更多操作',
    this.icon = Icons.more_vert,
    this.alignmentOffset,
    this.iconButtonPadding = EdgeInsets.zero,
    this.iconButtonConstraints =
        const BoxConstraints(minWidth: 40, minHeight: 40),
  });

  final List<Widget> menuChildren;
  final String tooltip;
  final IconData icon;
  final Offset? alignmentOffset;
  final EdgeInsetsGeometry iconButtonPadding;
  final BoxConstraints iconButtonConstraints;

  @override
  Widget build(BuildContext context) {
    final offset = alignmentOffset ?? S1MenuSpec.underAnchorOffset(context);
    return MenuAnchor(
      style: S1MenuSpec.anchoredMenuStyle(context),
      alignmentOffset: offset,
      reservedPadding: S1MenuSpec.reservedPadding,
      crossAxisUnconstrained: false,
      menuChildren: menuChildren,
      builder: (context, controller, child) {
        return IconButton(
          padding: iconButtonPadding,
          constraints: iconButtonConstraints,
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}
