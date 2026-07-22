import 'package:flutter/material.dart';

import '../models/whats_new_entry.dart';

/// 版本块列表（Dialog 与历史页共用）。
class WhatsNewEntryList extends StatelessWidget {
  const WhatsNewEntryList({
    super.key,
    required this.entries,
    this.dense = false,
  });

  final List<WhatsNewEntry> entries;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final gap = dense ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          _VersionBlock(
            entry: entries[i],
            scheme: scheme,
            textTheme: textTheme,
            dense: dense,
          ),
        ],
      ],
    );
  }
}

class _VersionBlock extends StatelessWidget {
  const _VersionBlock({
    required this.entry,
    required this.scheme,
    required this.textTheme,
    required this.dense,
  });

  final WhatsNewEntry entry;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final titleStyle = dense
        ? textTheme.titleSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          )
        : textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          );
    final dateStyle = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final bulletStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.version, style: titleStyle),
        if (entry.date.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(entry.date, style: dateStyle),
        ],
        if (entry.highlights.isNotEmpty) ...[
          SizedBox(height: dense ? 8 : 12),
          for (final line in entry.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: bulletStyle),
                  Expanded(child: Text(line, style: bulletStyle)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
