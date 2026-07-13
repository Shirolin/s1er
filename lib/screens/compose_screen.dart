import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../providers/api_service_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/compose_draft_store.dart';
import '../utils/quote_builder.dart';
import '../utils/s1_snack_bar.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({
    super.key,
    this.tid,
    this.fid,
    this.draftId,
    this.reppost,
  });

  final String? tid;
  final String? fid;
  final String? draftId;
  final String? reppost;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _redirectedToLogin = false;
  ComposeDraft? _draft;
  bool _includeQuote = true;

  bool get _hasValidTid => widget.tid != null && widget.tid!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.draftId != null) {
      _draft = ComposeDraftStore.take(widget.draftId!);
      _includeQuote = _draft != null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(authStateProvider).isLoggedIn && !_redirectedToLogin) {
        _redirectedToLogin = true;
        // 勿 pop 再 push：会在 Web 上触发 disposed EngineFlutterView 断言刷屏
        context.push('/login');
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String get _title {
    if (!_hasValidTid) return '无法回复';
    if (_draft != null && _draft!.displayFloor > 0) {
      return '回复 #${_draft!.displayFloor} 楼';
    }
    if (_draft != null) return '回复楼层';
    return '回复主题';
  }

  Future<void> _submit() async {
    if (!_hasValidTid || widget.fid == null || widget.fid!.isEmpty) {
      S1SnackBar.show(context, message: '缺少主题信息，请返回重试', bottomClearance: 16);
      return;
    }

    final userText = _messageController.text;
    if (userText.trim().isEmpty && !(_draft != null && _includeQuote)) return;

    setState(() => _isSubmitting = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final message = _draft != null && _includeQuote
          ? QuoteBuilder.buildMessageWithQuote(
              post: _draft!.post,
              tid: widget.tid!,
              userText: userText,
              includeQuote: true,
            )
          : userText;

      final result = await apiService.sendPost(
        fid: widget.fid!,
        tid: widget.tid!,
        message: message,
        reppost: widget.reppost ?? _draft?.post.pid,
        noticeAuthor: _draft != null && _includeQuote ? _draft!.post.author : null,
        noticeAuthorMsg:
            _draft != null && _includeQuote ? _draft!.post.message : null,
      );

      if (mounted) {
        if (result.isSuccess) {
          S1SnackBar.show(context, message: '回复成功', bottomClearance: 16);
          context.pop(result);
        } else {
          S1SnackBar.show(
            context,
            message: result.error ?? '回复失败',
            bottomClearance: 16,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '$e', bottomClearance: 16);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _removeQuote() {
    setState(() => _includeQuote = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!_hasValidTid) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('无法回复'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '当前仅支持回复已有主题，请从主题页进入。',
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(_title),
        actions: [
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? Text(
                    '发送中…',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  )
                : const Text('发送'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_draft != null && _includeQuote)
              _QuotePreviewCard(
                post: _draft!.post,
                displayFloor: _draft!.displayFloor,
                onRemove: _removeQuote,
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: _draft != null && _includeQuote
                      ? '输入回复内容…'
                      : '输入回复内容...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotePreviewCard extends StatelessWidget {
  const _QuotePreviewCard({
    required this.post,
    required this.displayFloor,
    required this.onRemove,
  });

  final Post post;
  final int displayFloor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final preview = QuoteBuilder.previewText(post.message);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayFloor > 0
                        ? '引用 #$displayFloor 楼 · ${post.author}'
                        : '引用 ${post.author}',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '移除引用',
              onPressed: onRemove,
              icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
