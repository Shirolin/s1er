import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rate_form.dart';
import '../providers/post_provider.dart';
import '../theme/app_theme.dart';
import '../utils/s1_snack_bar.dart';

/// 打开评分弹窗：预取表单 → 填写 → 提交 → 刷新评分历史。
Future<void> showRateDialog(
  BuildContext context,
  WidgetRef ref, {
  required String tid,
  required String pid,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _RateDialog(tid: tid, pid: pid),
  );
}

class _RateDialog extends ConsumerStatefulWidget {
  const _RateDialog({required this.tid, required this.pid});

  final String tid;
  final String pid;

  @override
  ConsumerState<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends ConsumerState<_RateDialog> {
  RateFormOptions? _options;

  late final TextEditingController _reasonController;
  String _score = '0';
  bool _notifyAuthor = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _fetchForm();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchForm() async {
    final options = await ref.read(apiServiceProvider).fetchRateForm(
          tid: widget.tid,
          pid: widget.pid,
        );
    if (!mounted) return;

    if (options.hasError) {
      Navigator.of(context).pop();
      S1SnackBar.show(context, message: options.error!);
      return;
    }

    setState(() {
      _options = options;
      _score = options.scoreOptions.first;
    });
  }

  Future<void> _submit() async {
    if (_score == '0') {
      S1SnackBar.show(context, message: '请选择评分分值');
      return;
    }

    setState(() => _submitting = true);
    try {
      final error = await ref.read(apiServiceProvider).submitRate(
            tid: widget.tid,
            pid: widget.pid,
            score1: _score,
            reason: _reasonController.text.trim(),
            notifyAuthor: _notifyAuthor,
          );
      if (!mounted) return;

      if (error != null) {
        S1SnackBar.show(context, message: error);
        return;
      }

      await ref
          .read(postProvider(widget.tid).notifier)
          .loadFullRateLog(widget.pid);

      if (!mounted) return;
      Navigator.of(context).pop();
      S1SnackBar.show(context, message: '评分成功');
    } catch (e) {
      if (!mounted) return;
      S1SnackBar.show(context, message: '评分失败: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ready = _options != null;

    return AlertDialog(
      title: Text('评分', style: textTheme.titleLarge),
      content: _buildContent(context),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: ready
          ? [
              TextButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text('确定'),
              ),
            ]
          : null,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_options == null) {
      return const SizedBox(
        width: 280,
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final options = _options!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reasonPresets =
        options.reasonPresets.where((preset) => preset.isNotEmpty).toList();

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormFieldSection(
            label: '战斗力',
            child: InputDecorator(
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _score,
                  style: textTheme.bodyLarge,
                  icon: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                  items: options.scoreOptions
                      .map(
                        (score) => DropdownMenuItem(
                          value: score,
                          child: Text(score),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _score = value);
                        },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _FormFieldSection(
            label: '理由',
            child: TextField(
              controller: _reasonController,
              enabled: !_submitting,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '可选评分理由',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (reasonPresets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reasonPresets.map((preset) {
                final selected = _reasonController.text == preset;
                return ActionChip(
                  label: Text(preset),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: selected
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  labelStyle: textTheme.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  side: BorderSide.none,
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _reasonController.text = preset),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: S1Shape.medium,
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('通知作者', style: textTheme.bodyLarge),
              value: _notifyAuthor,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _notifyAuthor = value ?? false),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldSection extends StatelessWidget {
  const _FormFieldSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
