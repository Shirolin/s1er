import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../utils/s1_snack_bar.dart';

class ComposeScreen extends ConsumerStatefulWidget {

  const ComposeScreen({super.key, this.tid, this.fid});
  final String? tid;
  final String? fid;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final apiService = ApiService(ref.read(httpClientProvider));
      final error = await apiService.sendPost(
        fid: widget.fid ?? '',
        tid: widget.tid ?? '',
        message: _messageController.text,
      );

      if (mounted) {
        if (error == null) {
          S1SnackBar.show(context, message: '回复成功', bottomClearance: 16);
          context.pop(true);
        } else {
          S1SnackBar.show(context, message: error, bottomClearance: 16);
        }
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '$e', bottomClearance: 16);
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.tid != null ? '回复' : '发帖'),
        actions: [
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发送'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '输入回复内容...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
