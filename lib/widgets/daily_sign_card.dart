import 'package:flutter/material.dart';

import '../models/attendance_result.dart';
import '../theme/app_theme.dart';

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
    final failed = result?.outcome == AttendanceOutcome.failed ||
        result?.outcome == AttendanceOutcome.unknown;

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(
              signed
                  ? Icons.check_circle_outline
                  : Icons.calendar_month_outlined,
              color: signed ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signed ? '今日已签到' : '每日签到',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result?.message ?? '点击完成今日 Discuz 签到',
                    style: textTheme.bodySmall?.copyWith(
                      color: failed ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (signed)
              Icon(Icons.done, color: scheme.primary)
            else
              FilledButton(
                onPressed: isSubmitting ? null : onSign,
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
  }
}
