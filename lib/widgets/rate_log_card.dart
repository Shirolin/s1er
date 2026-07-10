import 'package:flutter/material.dart';
import '../models/rate_log.dart';
import '../theme/app_theme.dart';

class RateLogCard extends StatefulWidget {
  const RateLogCard({super.key, required this.rateLog});
  final PostRateLog rateLog;

  @override
  State<RateLogCard> createState() => _RateLogCardState();
}

class _RateLogCardState extends State<RateLogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rateLog = widget.rateLog;
    final isPositive = rateLog.totalScore >= 0;
    final accentColor = isPositive ? scheme.primary : scheme.error;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: S1Shape.cardShape,
      child: InkWell(
        borderRadius: S1Shape.medium,
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                totalScore: rateLog.totalScore,
                participantCount: rateLog.participantCount,
                accentColor: accentColor,
                expanded: _expanded,
              ),
              if (_expanded) ...[
                const Divider(height: 1, indent: 12, endIndent: 12),
                ...rateLog.entries.map(
                  (entry) => _EntryRow(entry: entry, accentColor: accentColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalScore,
    required this.participantCount,
    required this.accentColor,
    required this.expanded,
  });

  final int totalScore;
  final int participantCount;
  final Color accentColor;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sign = totalScore >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '评分 $sign$totalScore',
            style: textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($participantCount人)',
            style: textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.accentColor});

  final RateLog entry;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sign = entry.score >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              entry.username,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$sign${entry.score}',
            style: textTheme.labelMedium?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.reason.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                entry.reason,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
