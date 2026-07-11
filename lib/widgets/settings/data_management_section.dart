import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../providers/auth_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/poll_vote_cache.dart';
import '../../theme/app_theme.dart';
import '../../utils/s1_snack_bar.dart';
import 'settings_section_header.dart';

class DataManagementSection extends ConsumerStatefulWidget {
  const DataManagementSection({super.key});

  @override
  ConsumerState<DataManagementSection> createState() =>
      _DataManagementSectionState();
}

class _DataManagementSectionState extends ConsumerState<DataManagementSection> {
  bool _clearingHistory = false;
  bool _clearingVotes = false;
  bool _resettingSettings = false;
  bool _loggingOut = false;

  Future<void> _confirmAction({
    required String title,
    required String content,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    bool isDestructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          if (isDestructive)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
              ),
              child: Text(confirmLabel),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
        ],
      ),
    );
    if (confirmed == true) {
      await onConfirm();
    }
  }

  Future<void> _runTask({
    required bool current,
    required ValueSetter<bool> setBusy,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (current) return;
    setState(() => setBusy(true));
    try {
      await action();
      if (mounted) {
        S1SnackBar.show(context, message: successMessage);
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '操作失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => setBusy(false));
      }
    }
  }

  Future<void> _clearReadingHistory() async {
    await _confirmAction(
      title: '清空阅读历史',
      content: '将删除当前账号的全部阅读记录，此操作不可恢复。',
      confirmLabel: '清空',
      isDestructive: true,
      onConfirm: () => _runTask(
        current: _clearingHistory,
        setBusy: (value) => _clearingHistory = value,
        successMessage: '已清空阅读历史',
        action: () => ref.read(readingHistoryProvider.notifier).clearAll(),
      ),
    );
  }

  Future<void> _clearPollVotes() async {
    final rawUid = ref.read(authStateProvider).user?.uid;
    final uid = rawUid == null || rawUid.isEmpty ? '' : rawUid;
    if (uid.isEmpty) return;

    await _confirmAction(
      title: '清空本地投票状态',
      content: '将删除当前账号保存的投票选择缓存，不会影响服务器上的投票结果。',
      confirmLabel: '清空',
      isDestructive: true,
      onConfirm: () => _runTask(
        current: _clearingVotes,
        setBusy: (value) => _clearingVotes = value,
        successMessage: '已清空本地投票状态',
        action: () => PollVoteCache(Hive.box('cache'), uid).clearAll(),
      ),
    );
  }

  Future<void> _resetAppearanceSettings() async {
    await _confirmAction(
      title: '重置显示与主题设置',
      content: '将恢复主题、字号、图片显示和阅读历史记录开关的默认值。',
      confirmLabel: '重置',
      onConfirm: () => _runTask(
        current: _resettingSettings,
        setBusy: (value) => _resettingSettings = value,
        successMessage: '已恢复默认设置',
        action: () async {
          ref.read(settingsProvider.notifier).resetAppearanceSettings();
        },
      ),
    );
  }

  Future<void> _logout() async {
    if (!ref.read(authStateProvider).isLoggedIn) return;

    await _confirmAction(
      title: '退出登录',
      content: '将清除当前会话并切换到未登录状态。',
      confirmLabel: '退出登录',
      isDestructive: true,
      onConfirm: () => _runTask(
        current: _loggingOut,
        setBusy: (value) => _loggingOut = value,
        successMessage: '已退出登录',
        action: () => ref.read(authStateProvider.notifier).logout(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final hasVoteCache =
        authState.isLoggedIn && (authState.user?.uid.isNotEmpty ?? false);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color:
          scheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '数据管理'),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.history_toggle_off_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('清空阅读历史'),
              subtitle: Text(
                '只删除当前账号的阅读记录',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              trailing: _buildTrailingSpinner(_clearingHistory),
              onTap: _clearingHistory
                  ? null
                  : () => unawaited(_clearReadingHistory()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.how_to_vote_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('清空本地投票状态'),
              subtitle: Text(
                hasVoteCache ? '只删除当前账号保存的投票选择缓存' : '登录后可清理当前账号的投票选择缓存',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              trailing: _buildTrailingSpinner(_clearingVotes),
              onTap: !hasVoteCache || _clearingVotes
                  ? null
                  : () => unawaited(_clearPollVotes()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.restart_alt_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('重置显示与主题设置'),
              subtitle: Text(
                '恢复主题、字号、图片显示和阅读历史记录开关的默认值',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              trailing: _buildTrailingSpinner(_resettingSettings),
              onTap: _resettingSettings
                  ? null
                  : () => unawaited(_resetAppearanceSettings()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            if (authState.isLoggedIn) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text(
                  '退出登录并清除会话',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                ),
                subtitle: Text(
                  '清除当前会话 Cookie，保留本地阅读历史与主题设置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                trailing: _buildTrailingSpinner(_loggingOut),
                onTap: _loggingOut ? null : () => unawaited(_logout()),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: const RoundedRectangleBorder(
                  borderRadius: S1Shape.small,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildTrailingSpinner(bool busy) {
    if (!busy) return null;
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
