import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/s1_haptics.dart';
import 'settings_section_header.dart';

class FontSizeSection extends ConsumerWidget {
  const FontSizeSection({super.key});

  /// 档位文案，按 [S1Typography.bodySizes] 的升序一一对应（无第二份档位表）。
  static const _labels = <String>['小', '标准', '大', '超大', '特大'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));
    final notifier = ref.read(settingsProvider.notifier);
    assert(
      _labels.length == S1Typography.bodySizes.length,
      '字号档位与文案数量不一致',
    );

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
                segments: [
                  for (var i = 0; i < _labels.length; i++)
                    ButtonSegment<int>(
                      value: S1Typography.bodySizes[i],
                      label: Text(_labels[i]),
                    ),
                ],
                selected: {fontSize},
                onSelectionChanged: (v) {
                  S1Haptics.selection();
                  notifier.setFontSize(v.first);
                },
                showSelectedIcon: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
