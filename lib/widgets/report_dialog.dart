import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_form.dart';
import '../providers/report_action_provider.dart';
import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';

Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String tid,
  required String pid,
  String? fid,
  int page = 1,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReportDialog(
      target: (tid: tid, pid: pid, fid: fid, page: page),
    ),
  );
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({required this.target});

  final ReportTarget target;

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  ReportFormOptions? _options;
  String? _reason;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchForm();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchForm() async {
    setState(() => _options = null);
    final options = await ref.read(reportFormProvider(widget.target).future);
    if (!mounted) return;
    setState(() {
      _options = options;
      if (!options.hasError && options.reasons.isNotEmpty) {
        _reason = options.reasons.first;
      }
    });
  }

  Future<void> _submit() async {
    if (_options == null || _options!.hasError || _submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    S1Haptics.medium();
    setState(() => _submitting = true);
    final error =
        await ref.read(reportActionControllerProvider(widget.target)).submit(
              form: _options!,
              reason: _reason!,
              message: _messageController.text,
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      S1SnackBar.error(context, message: error);
      return;
    }
    S1SnackBar.success(context, message: '举报成功');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: Text('举报', style: Theme.of(context).textTheme.titleLarge),
        content: _buildContent(context, options),
        actions: _buildActions(context, options),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ReportFormOptions? options) {
    if (options == null) {
      return const SizedBox(
        width: 300,
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (options.hasError) {
      return SizedBox(
        width: 300,
        child: Text(
          options.error!,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return SizedBox(
      width: 360,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: '举报原因'),
              items: options.reasons
                  .map(
                    (reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _reason = value),
              validator: (value) => value == null ? '请选择举报原因' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 200,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '具体说明',
                hintText: '请简要说明举报原因',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请填写具体说明' : null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget>? _buildActions(
    BuildContext context,
    ReportFormOptions? options,
  ) {
    if (options == null) return null;
    if (options.hasError) {
      return [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(options.retryable ? '取消' : '关闭'),
        ),
        if (options.retryable)
          FilledButton(
            onPressed: _submitting ? null : _fetchForm,
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
            : const Text('提交举报'),
      ),
    ];
  }
}
