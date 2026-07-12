import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rate_form.dart';
import '../providers/post_provider.dart';
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
    barrierDismissible: false,
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
  String? _loadError;

  late final TextEditingController _reasonController;
  String _score = '0';
  bool _notifyAuthor = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
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

    return AlertDialog(
      title: Text('评分', style: textTheme.titleLarge),
      content: _buildContent(context),
      actions: _options == null
          ? null
          : [
              TextButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确定'),
              ),
            ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loadError != null) {
      return Text(_loadError!);
    }
    if (_options == null) {
      return const SizedBox(
        width: 200,
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final options = _options!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledRow(
            label: '战斗力',
            child: DropdownButton<String>(
              isExpanded: true,
              value: _score,
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
          const SizedBox(height: 12),
          _LabeledRow(
            label: '理由',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reasonController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      hintText: '可选评分理由',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: null,
                  hint: Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
                  underline: const SizedBox.shrink(),
                  items: options.reasonPresets
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(preset.isEmpty ? '（无）' : preset),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            _reasonController.text = value;
                          }
                        },
                ),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('通知作者', style: textTheme.bodyMedium),
            value: _notifyAuthor,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _notifyAuthor = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: textTheme.bodyMedium),
        ),
        Expanded(child: child),
      ],
    );
  }
}
