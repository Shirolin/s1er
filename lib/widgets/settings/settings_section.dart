import 'package:flutter/material.dart';

import 'about_settings_section.dart';
import 'browsing_settings_section.dart';
import 'data_management_section.dart';
import 'font_size_section.dart';
import 'theme_settings_section.dart';

/// 设置页内容：主题、文字、浏览、数据管理与关于。
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
        BrowsingSettingsSection(),
        SizedBox(height: 16),
        DataManagementSection(),
        SizedBox(height: 16),
        AboutSettingsSection(),
      ],
    );
  }
}
