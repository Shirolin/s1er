import 'package:flutter/material.dart';

/// Compose 底部 BBCode 格式快捷条（横向滚动）。
///
/// 仅负责触发回调；选区包裹与 URL dialog 由调用方处理。
class ComposeBbcodeToolbar extends StatelessWidget {
  const ComposeBbcodeToolbar({
    super.key,
    required this.busy,
    required this.onWrap,
    required this.onInsertUrl,
  });

  final bool busy;
  final void Function(String openTag, String closeTag) onWrap;
  final VoidCallback onInsertUrl;

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
              tooltip: '删除线',
              icon: Icons.format_strikethrough,
              enabled: !busy,
              onPressed: () => onWrap('[s]', '[/s]'),
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
          ],
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
