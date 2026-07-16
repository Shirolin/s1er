import 'package:flutter/material.dart';

import 'about_settings_section.dart';
import 'blacklist_settings_section.dart';
import 'browsing_settings_section.dart';
import 'data_management_section.dart';
import 'download_cache_settings_section.dart';
import 'font_size_section.dart';
import 'share_settings_section.dart';
import 'theme_settings_section.dart';

/// 设置页内容：主题、文字、下载与缓存、浏览、黑名单、数据管理与关于。
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
        DownloadCacheSettingsSection(),
        SizedBox(height: 16),
        BrowsingSettingsSection(),
        SizedBox(height: 16),
        ShareSettingsSection(),
        SizedBox(height: 16),
        BlacklistSettingsSection(),
        SizedBox(height: 16),
        DataManagementSection(),
        SizedBox(height: 16),
        AboutSettingsSection(),
      ],
    );
  }
}
