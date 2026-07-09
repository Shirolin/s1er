import 'package:flutter/material.dart';

/// M3 弹出菜单项：48dp 高度、24dp 图标、12dp 间距、labelLarge 排版。
PopupMenuItem<T> s1PopupMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool enabled = true,
  bool destructive = false,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    height: 48,
    child: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final color = destructive ? scheme.error : null;
        final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: color);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Text(label, style: labelStyle),
          ],
        );
      },
    ),
  );
}
