import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../models/quote_info.dart';
import '../providers/auth_provider.dart';
import '../providers/compose_provider.dart';
import '../services/external_image_upload_service.dart';
import '../theme/app_theme.dart';
import '../utils/compose_draft_store.dart';
import '../utils/quote_builder.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/compose_emoticon_panel.dart';
import '../widgets/s1_confirm_dialog.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({
    super.key,
    this.tid,
    this.fid,
    this.draftId,
    this.reppost,
    this.subject,
  });

  final String? tid;
  final String? fid;
  final String? draftId;
  final String? reppost;
  final String? subject;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeUploadedImage {
  const _ComposeUploadedImage({required this.url, required this.label});

  final String url;
  final String label;
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _redirectedToLogin = false;
  bool _allowPop = false;
  bool _showEmoticonPanel = false;
  ComposeDraft? _draft;
  bool _includeQuote = true;
  QuoteInfo? _quoteInfo;
  bool _quotePrefetching = false;
  String? _quotePrefetchError;
  final List<_ComposeUploadedImage> _uploadedImages = [];

  bool get _hasValidTid => widget.tid != null && widget.tid!.isNotEmpty;

  String? get _quotePid => widget.reppost ?? _draft?.post.pid;

  String? get _subjectLabel {
    final subject = widget.subject?.trim();
    if (subject == null || subject.isEmpty) return null;
    return subject;
  }

  bool get _quoting =>
      _draft != null && _includeQuote && _quoteInfo != null;

  bool get _isDirty =>
      _messageController.text.trim().isNotEmpty || _uploadedImages.isNotEmpty;

  bool get _canSubmit {
    final busy = _isSubmitting || _isUploadingImage || _quotePrefetching;
    if (busy) return false;
    final hasText = _messageController.text.trim().isNotEmpty;
    return hasText || _quoting;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
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
        return;
      }
      _prefetchOfficialQuote();
    });
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _prefetchOfficialQuote() async {
    final tid = widget.tid;
    final pid = _quotePid;
    if (tid == null ||
        tid.isEmpty ||
        pid == null ||
        pid.isEmpty ||
        !_includeQuote) {
      return;
    }

    setState(() {
      _quotePrefetching = true;
      _quotePrefetchError = null;
    });

    final info = await ref.read(composeControllerProvider).prefetchQuote(
          tid: tid,
          pid: pid,
        );

    if (!mounted) return;
    setState(() {
      _quotePrefetching = false;
      _quoteInfo = info;
      if (info == null) {
        _quotePrefetchError = '无法加载官方引用信息，仍可纯文本回复';
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
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

  void _insertAtCursor(String snippet) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, snippet);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  void _toggleEmoticonPanel() {
    FocusScope.of(context).unfocus();
    setState(() => _showEmoticonPanel = !_showEmoticonPanel);
  }

  void _insertEmoticon(String entity) {
    _insertAtCursor(entity);
  }

  void _removeUploadedImage(_ComposeUploadedImage image) {
    final tag = '[img]${image.url}[/img]';
    final text = _messageController.text;
    final next = text.replaceFirst(tag, '');
    setState(() {
      _uploadedImages.removeWhere((item) => item.url == image.url);
      _messageController.text = next;
    });
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage || _isSubmitting) return;

    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await ref.read(composeControllerProvider).uploadImage(
            bytes: bytes,
            filename: file.name,
          );
      if (!mounted) return;
      final label = file.name.trim().isEmpty ? '图片' : file.name;
      setState(() {
        _uploadedImages.add(_ComposeUploadedImage(url: url, label: label));
      });
      _insertAtCursor('[img]$url[/img]');
      S1SnackBar.show(context, message: '图片已插入', bottomClearance: 72);
    } on ExternalImageUploadException catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: e.message, bottomClearance: 72);
      }
    } catch (_) {
      if (mounted) {
        S1SnackBar.show(context, message: '图片上传失败', bottomClearance: 72);
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_hasValidTid || widget.fid == null || widget.fid!.isEmpty) {
      S1SnackBar.show(
        context,
        message: '缺少主题信息，请返回重试',
        bottomClearance: 72,
      );
      return;
    }

    if (_isUploadingImage) {
      S1SnackBar.show(
        context,
        message: '图片仍在上传，请稍候',
        bottomClearance: 72,
      );
      return;
    }

    final userText = _messageController.text.trim();
    final quoting = _quoting;
    if (userText.isEmpty && !quoting) return;

    if (_includeQuote &&
        _quotePid != null &&
        _quotePid!.isNotEmpty &&
        _quoteInfo == null &&
        !_quotePrefetching) {
      S1SnackBar.show(
        context,
        message: _quotePrefetchError ?? '引用信息未就绪，请移除引用或稍后重试',
        bottomClearance: 72,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(composeControllerProvider).submitReply(
            tid: widget.tid!,
            fid: widget.fid!,
            message: userText,
            quoteInfo: quoting ? _quoteInfo : null,
          );

      if (mounted) {
        if (result.isSuccess) {
          S1SnackBar.show(context, message: '回复成功', bottomClearance: 16);
          setState(() => _allowPop = true);
          context.pop(result);
        } else {
          S1SnackBar.show(
            context,
            message: result.error ?? '回复失败',
            bottomClearance: 72,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '$e', bottomClearance: 72);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _removeQuote() {
    setState(() {
      _includeQuote = false;
      _quoteInfo = null;
      _quotePrefetchError = null;
    });
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _allowPop) return;
    if (!_isDirty) return;

    final discard = await showS1ConfirmDialog(
      context,
      title: '放弃回复？',
      content: '未发送的内容将丢失。',
      confirmLabel: '放弃',
      destructive: true,
    );
    if (!mounted || !discard) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = _isSubmitting || _isUploadingImage || _quotePrefetching;
    final subject = _subjectLabel;

    if (!_hasValidTid) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          elevation: 0,
          title: Text('无法回复', style: textTheme.titleLarge),
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

    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          elevation: 0,
          title: Text(_title, style: textTheme.titleLarge),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_draft != null && _includeQuote)
              _ComposeQuoteBanner(
                post: _draft!.post,
                displayFloor: _draft!.displayFloor,
                onRemove: _removeQuote,
                loading: _quotePrefetching,
                error: _quotePrefetchError,
              ),
            if (subject != null)
              _ComposeSubjectLine(subject: subject),
            if (_uploadedImages.isNotEmpty)
              _ComposeImageStrip(
                images: List.unmodifiable(_uploadedImages),
                onRemove: _removeUploadedImage,
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: textTheme.bodyLarge,
                onTap: () {
                  if (_showEmoticonPanel) {
                    setState(() => _showEmoticonPanel = false);
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  hintText: '输入回复内容…',
                  hintStyle: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: scheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showEmoticonPanel)
              ComposeEmoticonPanel(onSelect: _insertEmoticon),
            _ComposeBottomBar(
              busy: busy,
              canSubmit: _canSubmit,
              isSubmitting: _isSubmitting,
              isUploadingImage: _isUploadingImage,
              emoticonPanelOpen: _showEmoticonPanel,
              onPickImage: _pickAndUploadImage,
              onToggleEmoticon: _toggleEmoticonPanel,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeSubjectLine extends StatelessWidget {
  const _ComposeSubjectLine({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          '主题 · $subject',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ComposeQuoteBanner extends StatelessWidget {
  const _ComposeQuoteBanner({
    required this.post,
    required this.displayFloor,
    required this.onRemove,
    this.loading = false,
    this.error,
  });

  final Post post;
  final int displayFloor;
  final VoidCallback onRemove;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final preview = QuoteBuilder.previewText(post.message);

    return Material(
      color: scheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: scheme.primary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayFloor > 0
                              ? '引用 #$displayFloor 楼 · ${post.author}'
                              : '引用 ${post.author}',
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            error!,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ],
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
                ),
                IconButton(
                  tooltip: '移除引用',
                  onPressed: onRemove,
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeImageStrip extends StatelessWidget {
  const _ComposeImageStrip({
    required this.images,
    required this.onRemove,
  });

  final List<_ComposeUploadedImage> images;
  final ValueChanged<_ComposeUploadedImage> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final image = images[index];
            return InputChip(
              avatar: Icon(
                Icons.image_outlined,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              label: Text(
                image.label,
                style: textTheme.labelMedium,
              ),
              onDeleted: () => onRemove(image),
              deleteIconColor: scheme.onSecondaryContainer,
              backgroundColor: scheme.secondaryContainer,
              side: BorderSide.none,
            );
          },
        ),
      ),
    );
  }
}

class _ComposeBottomBar extends StatelessWidget {
  const _ComposeBottomBar({
    required this.busy,
    required this.canSubmit,
    required this.isSubmitting,
    required this.isUploadingImage,
    required this.emoticonPanelOpen,
    required this.onPickImage,
    required this.onToggleEmoticon,
    required this.onSubmit,
  });

  final bool busy;
  final bool canSubmit;
  final bool isSubmitting;
  final bool isUploadingImage;
  final bool emoticonPanelOpen;
  final VoidCallback onPickImage;
  final VoidCallback onToggleEmoticon;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: S1BottomBarStyle.background(scheme),
      elevation: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onToggleEmoticon,
                  icon: Icon(
                    emoticonPanelOpen
                        ? Icons.keyboard_outlined
                        : Icons.emoji_emotions_outlined,
                  ),
                  label: Text(emoticonPanelOpen ? '键盘' : '表情'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onPickImage,
                  icon: isUploadingImage
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(isUploadingImage ? '上传中' : '图片'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: canSubmit ? onSubmit : null,
                  child: isSubmitting
                      ? Text(
                          '发送中…',
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Text('发送'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
