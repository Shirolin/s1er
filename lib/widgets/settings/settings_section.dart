import 'package:flutter/material.dart';

import 'display_settings_section.dart';
import 'font_size_section.dart';
import 'theme_settings_section.dart';

/// 设置页内容：主题 + 文字 + 显示。
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ThemeSettingsSection(),
        SizedBox(height: 16),
        FontSizeSection(),
        SizedBox(height: 16),
        DisplaySettingsSection(),
      ],
    );
  }
}
