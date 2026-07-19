import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_icon_catalog.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/s1_haptics.dart';
import '../../utils/s1_snack_bar.dart';

/// Horizontal launcher-icon picker (Android / iOS).
class AppIconPicker extends ConsumerWidget {
  const AppIconPicker({super.key});

  static const _previewSize = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(settingsProvider.select((s) => s.appIcon));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showIosHint = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: AppIconCatalog.variants.map((variant) {
            final isSelected = selectedId == variant.id;
            return Expanded(
              child: Semantics(
                label: '${variant.label}图标',
                selected: isSelected,
                button: true,
                child: Tooltip(
                  message: variant.label,
                  child: InkWell(
                    onTap: () async {
                      if (isSelected) return;
                      S1Haptics.selection();
                      final confirmed = await _confirmIconChange(
                        context,
                        label: variant.label,
                      );
                      if (!confirmed || !context.mounted) return;
                      final ok = await ref
                          .read(settingsProvider.notifier)
                          .setAppIcon(variant.id);
                      if (!context.mounted) return;
                      if (!ok) {
                        S1SnackBar.show(context, message: '更换应用图标失败');
                      }
                    },
                    borderRadius: S1Shape.medium,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: _previewSize,
                            height: _previewSize,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Bare launcher-style preview — no frame/shadow.
                                ClipRRect(
                                  borderRadius: S1Shape.medium,
                                  child: Image.asset(
                                    variant.previewAsset,
                                    width: _previewSize,
                                    height: _previewSize,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            ColoredBox(
                                      color: scheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 12,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            variant.label,
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
              ),
            );
          }).toList(),
        ),
        if (showIosHint) ...[
          const SizedBox(height: 8),
          Text(
            '更换后系统会弹出确认提示',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Android 切换 activity-alias 常会杀进程；先确认避免被当成闪退。
/// iOS 由系统自行提示，此处直接放行。
Future<bool> _confirmIconChange(
  BuildContext context, {
  required String label,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return true;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('更换应用图标'),
        content: Text(
          '将切换为「$label」。更换后应用会关闭，需手动重新打开。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('更换并关闭'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
