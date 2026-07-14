import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import 'settings_section_header.dart';

/// 设置页入口：跳转到本地黑名单管理。
class BlacklistSettingsSection extends StatelessWidget {
  const BlacklistSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '黑名单'),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.block_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('本地黑名单'),
              subtitle: Text(
                '屏蔽指定用户的主题与楼层（仅本设备，不与论坛同步）',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(borderRadius: S1Shape.small),
              onTap: () => context.push('/blacklist'),
            ),
          ],
        ),
      ),
    );
  }
}
