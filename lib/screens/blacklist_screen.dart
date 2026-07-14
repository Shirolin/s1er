import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blacklist_record.dart';
import '../providers/blacklist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/s1_confirm_dialog.dart';

class BlacklistScreen extends ConsumerWidget {
  const BlacklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(blacklistProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        title: Text('本地黑名单', style: textTheme.titleLarge),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref),
        icon: const Icon(Icons.person_add_disabled_outlined),
        label: const Text('添加'),
      ),
      body: entries.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _BlacklistTile(
                  entry: entry,
                  onEdit: () => _showEditor(context, ref, existing: entry),
                  onDelete: () => _confirmDelete(context, ref, entry),
                );
              },
            ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '清空黑名单',
      content: '将移除全部本地屏蔽用户，此操作不可恢复。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(blacklistProvider.notifier).clearAll();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BlacklistRecord entry,
  ) async {
    final label =
        entry.username.isNotEmpty ? entry.username : 'UID ${entry.uid}';
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '移除屏蔽',
      content: '将「$label」从本地黑名单中移除？',
      confirmLabel: '移除',
      destructive: true,
    );
    if (confirmed) {
      ref.read(blacklistProvider.notifier).remove(entry.uid);
    }
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    BlacklistRecord? existing,
  }) async {
    final result = await showDialog<_BlacklistDraft>(
      context: context,
      builder: (ctx) => _BlacklistEditorDialog(existing: existing),
    );
    if (result == null) return;
    ref.read(blacklistProvider.notifier).upsert(
          uid: result.uid,
          username: result.username,
          reason: result.reason,
          scope: result.scope,
        );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_outlined, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '暂无屏蔽用户',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '可在楼层菜单或本页添加；仅影响本设备显示。',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlacklistTile extends StatelessWidget {
  const _BlacklistTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final BlacklistRecord entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title =
        entry.username.isNotEmpty ? entry.username : 'UID ${entry.uid}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: scheme.surfaceContainerLow,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'UID ${entry.uid}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '编辑',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '移除',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ),
            if (entry.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.reason.trim(),
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final scope in entry.scope)
                  Chip(
                    label: Text(_scopeLabel(scope)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlacklistDraft {
  const _BlacklistDraft({
    required this.uid,
    required this.username,
    required this.reason,
    required this.scope,
  });

  final String uid;
  final String username;
  final String reason;
  final List<String> scope;
}

class _BlacklistEditorDialog extends StatefulWidget {
  const _BlacklistEditorDialog({this.existing});

  final BlacklistRecord? existing;

  @override
  State<_BlacklistEditorDialog> createState() => _BlacklistEditorDialogState();
}

class _BlacklistEditorDialogState extends State<_BlacklistEditorDialog> {
  late final TextEditingController _uidController;
  late final TextEditingController _usernameController;
  late final TextEditingController _reasonController;
  late Set<String> _scopes;
  String? _uidError;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _uidController = TextEditingController(text: existing?.uid ?? '');
    _usernameController = TextEditingController(text: existing?.username ?? '');
    _reasonController = TextEditingController(text: existing?.reason ?? '');
    _scopes = {
      ...(existing?.scope.isNotEmpty == true
          ? existing!.scope
          : BlacklistRecord.defaultScopes),
    };
  }

  @override
  void dispose() {
    _uidController.dispose();
    _usernameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) {
      setState(() => _uidError = '请输入用户 UID');
      return;
    }
    Navigator.of(context).pop(
      _BlacklistDraft(
        uid: uid,
        username: _usernameController.text.trim(),
        reason: _reasonController.text.trim(),
        scope: BlacklistRecord.normalizeScopes(_scopes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(_editing ? '编辑屏蔽' : '添加屏蔽'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _uidController,
              enabled: !_editing,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '用户 UID',
                errorText: _uidError,
              ),
              onChanged: (_) {
                if (_uidError != null) setState(() => _uidError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名（可选）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text('作用域', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('主题列表'),
                  selected: _scopes.contains(BlacklistRecord.scopeThread),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _scopes.add(BlacklistRecord.scopeThread);
                      } else {
                        _scopes.remove(BlacklistRecord.scopeThread);
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('帖内楼层'),
                  selected: _scopes.contains(BlacklistRecord.scopePost),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _scopes.add(BlacklistRecord.scopePost);
                      } else {
                        _scopes.remove(BlacklistRecord.scopePost);
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('私信（预留）'),
                  selected: _scopes.contains(BlacklistRecord.scopePm),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _scopes.add(BlacklistRecord.scopePm);
                      } else {
                        _scopes.remove(BlacklistRecord.scopePm);
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_editing ? '保存' : '添加'),
        ),
      ],
    );
  }
}

String _scopeLabel(String scope) {
  switch (scope) {
    case BlacklistRecord.scopeThread:
      return '主题列表';
    case BlacklistRecord.scopePost:
      return '帖内楼层';
    case BlacklistRecord.scopePm:
      return '私信（预留）';
    default:
      return scope;
  }
}
