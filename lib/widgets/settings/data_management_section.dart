import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup/s1_backup_codec.dart';
import '../../theme/app_theme.dart';
import '../../utils/s1_snack_bar.dart';
import '../s1_confirm_dialog.dart';
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
  bool _exportingBackup = false;
  bool _importingBackup = false;
  bool _resettingSettings = false;
  bool _loggingOut = false;

  Future<void> _confirmAction({
    required String title,
    required String content,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    bool isDestructive = false,
  }) async {
    final confirmed = await showS1ConfirmDialog(
      context,
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      destructive: isDestructive,
    );
    if (confirmed) {
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
    } on _BackupCancelled {
      // User dismissed the file picker; no snackbar.
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
        action: () => ref.read(pollVoteCacheProvider(uid)).clearAll(),
      ),
    );
  }

  Future<void> _exportBackup() async {
    await _runTask(
      current: _exportingBackup,
      setBusy: (value) => _exportingBackup = value,
      successMessage: kIsWeb ? '备份已开始下载' : '已打开分享面板',
      action: () => exportS1Backup(ref),
    );
  }

  Future<void> _importBackup() async {
    await _confirmAction(
      title: '导入备份',
      content: '将以备份内容覆盖本地同名设置与同键记录（阅读历史、投票、黑名单）。'
          '不会导入 Cookie、密码或图片缓存。',
      confirmLabel: '选择文件',
      onConfirm: () => _runTask(
        current: _importingBackup,
        setBusy: (value) => _importingBackup = value,
        successMessage: '导入完成',
        action: () async {
          try {
            final result = await importS1Backup(ref);
            if (result == null) {
              throw _BackupCancelled();
            }
          } on S1BackupException catch (e) {
            throw Exception(e.message);
          }
        },
      ),
    );
  }

  Future<void> _resetAppearanceSettings() async {
    await _confirmAction(
      title: '重置显示与主题设置',
      content: '将恢复主题、字号、图片与缓存相关设置的默认值。',
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
    final hasVoteCache = ref.watch(
      authStateProvider.select(
        (auth) => auth.isLoggedIn && (auth.user?.uid.isNotEmpty ?? false),
      ),
    );
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
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
                Icons.upload_file_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('导出备份'),
              subtitle: Text(
                '导出设置、阅读历史、投票与黑名单（不含 Cookie / 图片）',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              trailing: _buildTrailingSpinner(_exportingBackup),
              onTap: _exportingBackup ? null : () => unawaited(_exportBackup()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.download_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('导入备份'),
              subtitle: Text(
                '从 .s1backup.zip / .zip 恢复；同键以备份为准覆盖',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              trailing: _buildTrailingSpinner(_importingBackup),
              onTap: _importingBackup ? null : () => unawaited(_importBackup()),
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
                '恢复主题、字号、图片与缓存相关设置的默认值',
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
            if (isLoggedIn) ...[
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

class _BackupCancelled implements Exception {}
