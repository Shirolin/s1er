import 'package:flutter/material.dart';

import '../models/attendance_result.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';

/// 每日签到卡片：纯展示，由调用方传入状态与回调。
class DailySignCard extends StatelessWidget {
  const DailySignCard({
    super.key,
    required this.isSubmitting,
    required this.result,
    required this.onSign,
  });

  final bool isSubmitting;
  final AttendanceResult? result;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final signed = result?.isSignedToday == true;
    final unavailable = result?.outcome == AttendanceOutcome.unavailable;
    final failed = !unavailable &&
        (result?.outcome == AttendanceOutcome.failed ||
            result?.outcome == AttendanceOutcome.unknown);
    // 插件被论坛停用时整块置灰冻结：入口不可点，也不给「稍后再试」的错觉。
    final mutedColor = scheme.onSurfaceVariant;

    final card = Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          signed || unavailable ? 16 : 12,
          14,
        ),
        child: Row(
          children: [
            Icon(
              signed
                  ? Icons.check_circle_outline
                  : unavailable
                      ? Icons.block_outlined
                      : Icons.calendar_month_outlined,
              color: signed
                  ? scheme.primary
                  : unavailable
                      ? mutedColor.withValues(alpha: S1Alpha.disabledIcon)
                      : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signed ? '今日已签到' : '每日签到',
                    style: textTheme.titleSmall?.copyWith(
                      color: unavailable ? mutedColor : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unavailable
                        ? '论坛已暂停签到插件'
                        : result?.message ?? '点击完成今日 Discuz 签到',
                    style: textTheme.bodySmall?.copyWith(
                      color: failed
                          ? scheme.error
                          : unavailable
                              ? mutedColor.withValues(alpha: S1Alpha.strong)
                              : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (signed)
              Icon(Icons.done, color: scheme.primary)
            else if (!unavailable)
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        S1Haptics.medium();
                        onSign();
                      },
                child: isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Text('签到'),
              ),
          ],
        ),
      ),
    );

    if (!unavailable) return card;
    return Semantics(
      enabled: false,
      label: '每日签到不可用：论坛已暂停签到插件',
      child: Tooltip(
        message: '论坛已暂停签到插件，恢复后会自动可用',
        child: card,
      ),
    );
  }
}
