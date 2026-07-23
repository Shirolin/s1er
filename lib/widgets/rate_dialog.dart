import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rate_form.dart';
import '../providers/rate_action_provider.dart';
import '../providers/thread_rate_logs_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
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
  String? _score;
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
    setState(() => _options = null);
    final options =
        await ref.read(rateFormProvider((widget.tid, widget.pid)).future);
    if (!mounted) return;

    setState(() {
      _options = options;
      if (!options.hasError) {
        _score = options.preferredDefaultScore;
        _notifyAuthor = options.notifyAuthorDefault;
      }
    });
  }

  Future<void> _submit() async {
    if (_score == null || _score == '0') {
      S1SnackBar.show(context, message: '请选择评分分值');
      return;
    }

    S1Haptics.medium();
    setState(() => _submitting = true);
    try {
      final error = await ref
          .read(rateActionControllerProvider((widget.tid, widget.pid)))
          .submit(
            score1: _score!,
            reason: _reasonController.text.trim(),
            notifyAuthor: _notifyAuthor,
            form: _options,
          );
      if (!mounted) return;

      if (error != null) {
        S1SnackBar.error(context, message: error);
        return;
      }

      await ref
          .read(threadRateLogsProvider(widget.tid).notifier)
          .loadFullRateLog(widget.pid);

      if (!mounted) return;
      S1SnackBar.success(context, message: '评分成功');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      S1SnackBar.error(context, message: '评分失败: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final options = _options;

    return AlertDialog(
      title: Text('评分', style: textTheme.titleLarge),
      content: _buildContent(context),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: _buildActions(context, options),
    );
  }

  List<Widget>? _buildActions(BuildContext context, RateFormOptions? options) {
    if (options == null) return null;
    if (options.hasError) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(options.retryable ? '取消' : '关闭'),
        ),
        if (options.retryable)
          FilledButton(
            onPressed: _fetchForm,
            child: const Text('重试'),
          ),
      ];
    }

    return [
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
    ];
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
    if (options.hasError) {
      return SizedBox(
        width: 280,
        child:
            Text(options.error!, style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final selectableScores = options.buildScoreOptions();
    final reasonPresets =
        options.reasonPresets.where((preset) => preset.isNotEmpty).toList();
    final totalScore = options.totalScore;
    final totalScoreLabel = totalScore == null
        ? null
        : '当前总战斗力：${totalScore > 0 ? '+' : ''}$totalScore';

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormFieldSection(
            label: '战斗力',
            supportingText: totalScoreLabel,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectableScores.map((score) {
                return FilterChip(
                  label: Text(score),
                  selected: _score == score,
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  onSelected: _submitting
                      ? null
                      : (selected) {
                          setState(() => _score = selected ? score : null);
                        },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _FormFieldSection(
            label: '理由',
            child: TextField(
              controller: _reasonController,
              enabled: !_submitting,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '可选评分理由',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                return FilterChip(
                  label: Text(preset),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  onSelected: _submitting
                      ? null
                      : (value) {
                          setState(() {
                            _reasonController.text = value ? preset : '';
                          });
                        },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: S1Shape.medium,
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('通知作者', style: textTheme.bodyLarge),
              value: _notifyAuthor,
              onChanged: _submitting || options.notifyAuthorDisabled
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
  const _FormFieldSection({
    required this.label,
    required this.child,
    this.supportingText,
  });

  final String label;
  final Widget child;
  final String? supportingText;

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
        if (supportingText != null) ...[
          const SizedBox(height: 2),
          Text(
            supportingText!,
            style:
                textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
