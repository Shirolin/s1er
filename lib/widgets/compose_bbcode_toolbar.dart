import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/author_color_adapter.dart';

/// Compose 底部 BBCode 格式快捷条（横向滚动）。
///
/// 仅负责触发回调；选区包裹与 dialog 由调用方处理。
class ComposeBbcodeToolbar extends StatelessWidget {
  const ComposeBbcodeToolbar({
    super.key,
    required this.busy,
    required this.onWrap,
    required this.onInsertUrl,
    required this.onWrapColor,
    required this.onInsertCreditHide,
  });

  final bool busy;
  final void Function(String openTag, String closeTag) onWrap;
  final VoidCallback onInsertUrl;
  final ValueChanged<String> onWrapColor;
  final VoidCallback onInsertCreditHide;

  /// Discuz 常用文字色（写入 `[color=#RRGGBB]`）。
  static const List<String> presetColorHexes = [
    '#FF0000',
    '#FF6600',
    '#008000',
    '#0000FF',
    '#800080',
    '#808080',
    '#000000',
    '#C0C0C0',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            _BbcodeToolButton(
              tooltip: '加粗',
              icon: Icons.format_bold,
              enabled: !busy,
              onPressed: () => onWrap('[b]', '[/b]'),
            ),
            _BbcodeToolButton(
              tooltip: '斜体',
              icon: Icons.format_italic,
              enabled: !busy,
              onPressed: () => onWrap('[i]', '[/i]'),
            ),
            _BbcodeToolButton(
              tooltip: '下划线',
              icon: Icons.format_underlined,
              enabled: !busy,
              onPressed: () => onWrap('[u]', '[/u]'),
            ),
            _BbcodeToolButton(
              tooltip: '删除线',
              icon: Icons.format_strikethrough,
              enabled: !busy,
              onPressed: () => onWrap('[s]', '[/s]'),
            ),
            _BbcodeColorButton(
              enabled: !busy,
              onSelected: onWrapColor,
            ),
            _BbcodeToolButton(
              tooltip: '引用',
              icon: Icons.format_quote_outlined,
              enabled: !busy,
              onPressed: () => onWrap('[quote]', '[/quote]'),
            ),
            _BbcodeToolButton(
              tooltip: '代码',
              icon: Icons.code,
              enabled: !busy,
              onPressed: () => onWrap('[code]', '[/code]'),
            ),
            _BbcodeToolButton(
              tooltip: '链接',
              icon: Icons.link,
              enabled: !busy,
              onPressed: onInsertUrl,
            ),
            _BbcodeToolButton(
              tooltip: '隐藏',
              icon: Icons.visibility_off_outlined,
              enabled: !busy,
              onPressed: () => onWrap('[hide]', '[/hide]'),
            ),
            _BbcodeToolButton(
              tooltip: '积分隐藏',
              icon: Icons.lock_outline,
              enabled: !busy,
              onPressed: onInsertCreditHide,
            ),
          ],
        ),
      ),
    );
  }
}

class _BbcodeColorButton extends StatelessWidget {
  const _BbcodeColorButton({
    required this.enabled,
    required this.onSelected,
  });

  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryHex = AuthorColorAdapter.toCssHex(scheme.primary);

    final swatches = <String>[
      ...ComposeBbcodeToolbar.presetColorHexes,
      if (!ComposeBbcodeToolbar.presetColorHexes
          .any((h) => h.toUpperCase() == primaryHex.toUpperCase()))
        primaryHex,
    ];

    return MenuAnchor(
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(S1Surface.card(scheme)),
      ),
      menuChildren: [
        for (final hex in swatches)
          MenuItemButton(
            onPressed: enabled
                ? () {
                    onSelected(hex);
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ColorDot(hex: hex),
                const SizedBox(width: 12),
                Text(hex, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          tooltip: '文字颜色',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(40, 40),
          ),
          onPressed: enabled
              ? () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
          icon: Icon(
            Icons.format_color_text,
            color: enabled ? scheme.primary : null,
          ),
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AuthorColorAdapter.parseCssColor(hex) ?? scheme.primary;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
        ),
      ),
    );
  }
}

class _BbcodeToolButton extends StatelessWidget {
  const _BbcodeToolButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(40, 40),
      ),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}
