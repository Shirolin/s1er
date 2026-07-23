import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/forum_name_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_desktop_scaffold.dart';

class HiddenForumsScreen extends ConsumerWidget {
  const HiddenForumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      settingsProvider.select((s) => s.hiddenForums),
    );
    final nameMap = ref.watch(fidToForumNameMapProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fids = hidden.toList()..sort();

    return S1DesktopScaffold(
      highlightedTab: 3,
      child: Scaffold(
        backgroundColor: S1Surface.page(scheme),
        appBar: AppBar(
          elevation: 0,
          title: Text('已屏蔽版块', style: textTheme.titleLarge),
          actions: [
            if (fids.isNotEmpty)
              IconButton(
                tooltip: '全部恢复',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () async {
                  S1Haptics.medium();
                  final confirmed = await showS1ConfirmDialog(
                    context,
                    title: '全部恢复',
                    content: '确定恢复全部已屏蔽的版块吗？',
                    confirmLabel: '全部恢复',
                  );
                  if (!confirmed || !context.mounted) return;
                  ref.read(settingsProvider.notifier).clearHiddenForums();
                  S1SnackBar.show(context, message: '已恢复全部版块');
                },
              ),
          ],
        ),
        body: fids.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 48,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text('暂无屏蔽的版块', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '在首页长按版块，或在版块页「更多」中可屏蔽',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount: fids.length,
                itemBuilder: (context, index) {
                  final fid = fids[index];
                  final name = nameMap[fid];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      // Theme ListTile 默认 horizontal: 8 是给设置 Card 内嵌用的；
                      // 独立卡片需更大左内边距，避免 leading 贴边。
                      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      leading: Icon(
                        Icons.forum_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text(name ?? '版块 #$fid'),
                      subtitle: name == null
                          ? null
                          : Text(
                              'fid $fid',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                      trailing: TextButton(
                        onPressed: () {
                          S1Haptics.selection();
                          ref.read(settingsProvider.notifier).unhideForum(fid);
                          S1SnackBar.show(context, message: '已取消屏蔽');
                        },
                        child: const Text('取消屏蔽'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
