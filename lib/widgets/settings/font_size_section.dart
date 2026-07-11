import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'settings_section_header.dart';

class FontSizeSection extends ConsumerWidget {
  const FontSizeSection({super.key});

  static final _sizes = <int, String>{
    12: '小',
    S1Typography.defaultBodySize: '标准',
    16: '大',
    18: '超大',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '文字大小'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: _sizes.entries
                    .map(
                      (e) => ButtonSegment<int>(
                        value: e.key,
                        label: Text(e.value),
                      ),
                    )
                    .toList(),
                selected: {fontSize},
                onSelectionChanged: (v) => notifier.setFontSize(v.first),
                showSelectedIcon: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
