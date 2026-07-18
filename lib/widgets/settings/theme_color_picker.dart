import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const _colorLabels = {
  'blue': '冷蓝',
  'sand': '暖沙',
  'purple': '紫色',
  'sage': '绿色',
  'rose': '玫红',
};

const _shortLabels = {
  'blue': '蓝',
  'sand': '沙',
  'purple': '紫',
  'sage': '绿',
  'rose': '玫',
};

class ThemeColorPicker extends StatelessWidget {
  const ThemeColorPicker({
    super.key,
    required this.selectedKey,
    required this.onChanged,
  });

  final String selectedKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: AppTheme.themeSeeds.entries.map((entry) {
        final key = entry.key;
        final color = entry.value;
        final isSelected = selectedKey == key;
        final checkColor = S1Contrast.on(color, scheme);

        return Semantics(
          label: '${_colorLabels[key] ?? key}主题',
          selected: isSelected,
          button: onChanged != null,
          child: Tooltip(
            message: _colorLabels[key] ?? key,
            child: InkWell(
              onTap: onChanged != null ? () => onChanged!(key) : null,
              borderRadius: S1Shape.full,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(
                                        alpha: S1Alpha.cardOverlay,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        if (isSelected)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: checkColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: color,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shortLabels[key] ?? key,
                      style: textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
