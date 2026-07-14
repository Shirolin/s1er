import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../models/quote_info.dart';
import '../providers/auth_provider.dart';
import '../providers/compose_provider.dart';
import '../providers/settings_provider.dart';
import '../services/external_image_upload_service.dart';
import '../theme/app_theme.dart';
import '../utils/compose_draft_store.dart';
import '../utils/compose_img_tags.dart';
import '../utils/compose_message_draft.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/quote_builder.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/bbcode_renderer.dart';
import '../widgets/compose_emoticon_panel.dart';
import '../widgets/quote_block.dart';
import '../widgets/s1_confirm_dialog.dart';

const _recentEmoticonsKey = 'compose_recent_emoticons';

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
  final _messageFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _redirectedToLogin = false;
  bool _allowPop = false;
  bool _showEmoticonPanel = false;
  ComposeDraft? _draft;
  bool _includeQuote = false;
  QuoteInfo? _quoteInfo;
  bool _quotePrefetching = false;
  String? _quotePrefetchError;
  final List<_ComposeUploadedImage> _uploadedImages = [];
  final Map<String, String> _imageLabelsByUrl = {};
  List<String> _recentEmoticons = [];
  Timer? _draftSaveTimer;
  bool _suppressDraftSave = false;
  ({Uint8List bytes, String filename})? _pendingUpload;

  bool get _hasValidTid => widget.tid != null && widget.tid!.isNotEmpty;

  String? get _quotePid => widget.reppost ?? _draft?.post.pid;

  String? get _subjectLabel {
    final subject = widget.subject?.trim();
    if (subject == null || subject.isEmpty) return null;
    return subject;
  }

  bool get _quoting => _includeQuote && _quoteInfo != null;

  bool get _isDirty =>
      _messageController.text.trim().isNotEmpty || _uploadedImages.isNotEmpty;

  bool get _canSubmit {
    final busy = _isSubmitting || _isUploadingImage || _quotePrefetching;
    if (busy) return false;
    final hasText = _messageController.text.trim().isNotEmpty;
    return hasText || _quoting;
  }

  bool get _canPreview {
    return _messageController.text.trim().isNotEmpty || _quoting;
  }

  String get _draftEntryKey {
    final tid = widget.tid ?? '';
    return ComposeMessageDraft.entryKey(tid: tid, reppost: _quotePid);
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _messageFocusNode.addListener(_onMessageFocusChanged);
    if (widget.draftId != null) {
      _draft = ComposeDraftStore.take(widget.draftId!);
    }
    final pid = _quotePid;
    _includeQuote = pid != null && pid.isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRecentEmoticons();
      _restoreMessageDraft();
      if (!ref.read(authStateProvider).isLoggedIn && !_redirectedToLogin) {
        _redirectedToLogin = true;
        // 勿 pop 再 push：会在 Web 上触发 disposed EngineFlutterView 断言刷屏
        context.push('/login');
        return;
      }
      _prefetchOfficialQuote();
    });
  }

  void _loadRecentEmoticons() {
    try {
      final store = ref.read(settingsStoreProvider);
      final raw = store.get<Object>(_recentEmoticonsKey);
      if (raw is! List) return;
      setState(() {
        _recentEmoticons =
            raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      });
    } on Object {
      // Provider 未注入（如部分 widget 测试）时跳过持久化最近表情。
    }
  }

  void _restoreMessageDraft() {
    final tid = widget.tid;
    if (tid == null || tid.isEmpty) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = ComposeMessageDraft.parseStore(
        store.get<Object>(ComposeMessageDraft.settingsKey),
      );
      final saved = ComposeMessageDraft.readMessage(drafts, _draftEntryKey);
      if (saved == null) return;
      _suppressDraftSave = true;
      _messageController.value = TextEditingValue(
        text: saved,
        selection: TextSelection.collapsed(offset: saved.length),
      );
      _suppressDraftSave = false;
      S1SnackBar.show(context, message: '已恢复草稿', bottomClearance: 72);
    } on Object {
      _suppressDraftSave = false;
    }
  }

  void _scheduleDraftSave() {
    if (_suppressDraftSave) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(ComposeMessageDraft.debounce, _persistDraft);
  }

  void _persistDraft() {
    final tid = widget.tid;
    if (tid == null || tid.isEmpty) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = ComposeMessageDraft.parseStore(
        store.get<Object>(ComposeMessageDraft.settingsKey),
      );
      final key = _draftEntryKey;
      final text = _messageController.text;
      final next = text.trim().isEmpty
          ? ComposeMessageDraft.removeEntry(drafts, key)
          : ComposeMessageDraft.upsert(drafts, key, text);
      store.put(
        ComposeMessageDraft.settingsKey,
        ComposeMessageDraft.toStoreValue(next),
      );
    } on Object {
      // 无 settings store 时跳过。
    }
  }

  void _clearMessageDraft() {
    _draftSaveTimer?.cancel();
    final tid = widget.tid;
    if (tid == null || tid.isEmpty) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = ComposeMessageDraft.parseStore(
        store.get<Object>(ComposeMessageDraft.settingsKey),
      );
      final next = ComposeMessageDraft.removeEntry(drafts, _draftEntryKey);
      store.put(
        ComposeMessageDraft.settingsKey,
        ComposeMessageDraft.toStoreValue(next),
      );
    } on Object {
      // 无 settings store 时跳过。
    }
  }

  void _onMessageChanged() {
    if (!mounted) return;
    final urls = extractImgUrls(_messageController.text);
    final next = <_ComposeUploadedImage>[
      for (final url in urls)
        _ComposeUploadedImage(
          url: url,
          label: _imageLabelsByUrl[url] ?? filenameFromUrl(url),
        ),
    ];
    setState(() {
      _uploadedImages
        ..clear()
        ..addAll(next);
    });
    _scheduleDraftSave();
  }

  void _onMessageFocusChanged() {
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

  String get _title {
    if (!_hasValidTid) return '无法回复';
    if (_draft != null && _draft!.displayFloor > 0) {
      return '回复 #${_draft!.displayFloor} 楼';
    }
    if (_draft != null || (_quotePid != null && _quotePid!.isNotEmpty)) {
      return '回复楼层';
    }
    return '回复主题';
  }

  void _toggleEmoticonPanel() {
    setState(() {
      _showEmoticonPanel = !_showEmoticonPanel;
      if (_showEmoticonPanel) {
        _messageFocusNode.unfocus();
      } else {
        _messageFocusNode.requestFocus();
      }
    });
  }

  void _insertEmoticon(String entity) {
    final selection = _messageController.selection;
    final start = selection.isValid ? selection.start : _messageController.text.length;
    final end = selection.isValid ? selection.end : _messageController.text.length;
    final result = insertEmoticonEntity(
      text: _messageController.text,
      start: start,
      end: end,
      entity: entity,
    );
    _messageController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    final next = pushRecentEmoticon(_recentEmoticons, entity);
    setState(() => _recentEmoticons = next);
    try {
      ref.read(settingsStoreProvider).put(_recentEmoticonsKey, next);
    } on Object {
      // 同上：无 settings store 时仅保留会话内最近列表。
    }
  }

  Future<void> _showPreview() async {
    final message = _messageController.text;
    if (!_canPreview) return;
    _messageFocusNode.unfocus();
    if (_showEmoticonPanel) {
      setState(() => _showEmoticonPanel = false);
    }
    final quoteInfo = _quoting ? _quoteInfo : null;
    final tid = widget.tid;

    await showModalBottomSheet<void>(
      context: context,
      elevation: 0,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: S1Shape.bottomSheetShape,
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        final height = MediaQuery.sizeOf(ctx).height * 0.65;
        final imageIndexCounter = PostImageIndexCounter();
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('预览', style: textTheme.titleMedium),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (quoteInfo != null)
                          QuoteBlock(
                            content: quoteInfo.noticeTrimStr,
                            imageIndexCounter: imageIndexCounter,
                            currentTid: tid,
                          ),
                        BbcodeRenderer(
                          bbcode: message.isEmpty ? '（无正文）' : message,
                          imageIndexCounter: imageIndexCounter,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('关闭'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    if (!_allowPop && _messageController.text.trim().isNotEmpty) {
      _persistDraft();
    }
    _messageController.removeListener(_onMessageChanged);
    _messageFocusNode.removeListener(_onMessageFocusChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _removeUploadedImage(_ComposeUploadedImage image) {
    final next = removeImgTag(_messageController.text, image.url);
    _imageLabelsByUrl.remove(image.url);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: next.length.clamp(0, next.length),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage || _isSubmitting) return;

    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingUpload = (bytes: bytes, filename: file.name);
    });
    await _uploadPendingImage();
  }

  Future<void> _uploadPendingImage() async {
    final pending = _pendingUpload;
    if (pending == null || _isUploadingImage || _isSubmitting) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await ref.read(composeControllerProvider).uploadImage(
            bytes: pending.bytes,
            filename: pending.filename,
          );
      if (!mounted) return;
      final label =
          pending.filename.trim().isEmpty ? '图片' : pending.filename;
      _imageLabelsByUrl[url] = label;
      final selection = _messageController.selection;
      final start =
          selection.isValid ? selection.start : _messageController.text.length;
      final end =
          selection.isValid ? selection.end : _messageController.text.length;
      final result = insertImgTagAt(
        text: _messageController.text,
        start: start,
        end: end,
        url: url,
      );
      _messageController.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursor),
      );
      setState(() => _pendingUpload = null);
      S1SnackBar.show(context, message: '图片已插入', bottomClearance: 72);
    } on ExternalImageUploadException catch (e) {
      if (mounted) {
        S1SnackBar.show(
          context,
          message: e.message,
          bottomClearance: 72,
          actionLabel: '重试',
          onAction: () {
            if (mounted) unawaited(_uploadPendingImage());
          },
        );
      }
    } catch (_) {
      if (mounted) {
        S1SnackBar.show(
          context,
          message: '图片上传失败',
          bottomClearance: 72,
          actionLabel: '重试',
          onAction: () {
            if (mounted) unawaited(_uploadPendingImage());
          },
        );
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
          _clearMessageDraft();
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
      content: '放弃后将清除本回复草稿。',
      confirmLabel: '放弃',
      destructive: true,
    );
    if (!mounted || !discard) return;
    _clearMessageDraft();
    setState(() => _allowPop = true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = _isSubmitting || _isUploadingImage || _quotePrefetching;
    final subject = _subjectLabel;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final showPanel = _showEmoticonPanel && keyboardInset <= 0;

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
            if (_includeQuote)
              _ComposeQuoteBanner(
                post: _draft?.post,
                displayFloor: _draft?.displayFloor ?? 0,
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
              child: _ComposeMessageField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                onTap: () {
                  if (_showEmoticonPanel) {
                    setState(() => _showEmoticonPanel = false);
                  }
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: AnimatedAlign(
                duration: S1Motion.medium,
                curve: S1Motion.standard,
                heightFactor: showPanel ? 1 : 0,
                alignment: Alignment.bottomCenter,
                child: ComposeEmoticonPanel(
                  onSelect: _insertEmoticon,
                  recent: _recentEmoticons,
                ),
              ),
            ),
            _ComposeBottomBar(
              busy: busy,
              canSubmit: _canSubmit,
              canPreview: _canPreview,
              isSubmitting: _isSubmitting,
              isUploadingImage: _isUploadingImage,
              emoticonPanelOpen: showPanel,
              onPickImage: _pickAndUploadImage,
              onToggleEmoticon: _toggleEmoticonPanel,
              onPreview: _showPreview,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// 正文 filled 输入：空态用 Highest 凹槽；有内容 / 聚焦时降到 Low，区分「内容态」。
class _ComposeMessageField extends StatelessWidget {
  const _ComposeMessageField({
    required this.controller,
    required this.focusNode,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasContent = controller.text.trim().isNotEmpty;
    final focused = focusNode.hasFocus;
    final active = hasContent || focused;
    final fillColor =
        active ? scheme.surfaceContainerLow : scheme.surfaceContainerHighest;

    return AnimatedContainer(
      duration: S1Motion.short,
      curve: S1Motion.standard,
      color: fillColor,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: textTheme.bodyLarge,
        onTap: onTap,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: '输入回复内容…',
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
          enabledBorder: hasContent
              ? UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: scheme.outlineVariant,
                    width: 1,
                  ),
                )
              : InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: scheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

class _ComposeSubjectLine extends StatefulWidget {
  const _ComposeSubjectLine({required this.subject});

  final String subject;

  @override
  State<_ComposeSubjectLine> createState() => _ComposeSubjectLineState();
}

class _ComposeSubjectLineState extends State<_ComposeSubjectLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainer,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '主题 · ${widget.subject}',
                  maxLines: _expanded ? null : 1,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: _expanded
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposeQuoteBanner extends StatelessWidget {
  const _ComposeQuoteBanner({
    this.post,
    this.displayFloor = 0,
    required this.onRemove,
    this.loading = false,
    this.error,
  });

  final Post? post;
  final int displayFloor;
  final VoidCallback onRemove;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final post = this.post;
    final preview =
        post == null ? '' : QuoteBuilder.previewText(post.message);
    final title = post == null
        ? '引用楼层'
        : displayFloor > 0
            ? '引用 #$displayFloor 楼 · ${post.author}'
            : '引用 ${post.author}';

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
                          title,
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
    final maxLabelWidth =
        (MediaQuery.sizeOf(context).width * 0.4).clamp(88.0, 120.0);

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
            return Tooltip(
              message: image.label,
              child: InputChip(
                avatar: Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
                label: SizedBox(
                  width: maxLabelWidth,
                  child: Text(
                    displayLabelForIndex(index),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium,
                  ),
                ),
                onDeleted: () => onRemove(image),
                deleteIcon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
                backgroundColor: scheme.secondaryContainer,
                side: BorderSide.none,
              ),
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
    required this.canPreview,
    required this.isSubmitting,
    required this.isUploadingImage,
    required this.emoticonPanelOpen,
    required this.onPickImage,
    required this.onToggleEmoticon,
    required this.onPreview,
    required this.onSubmit,
  });

  final bool busy;
  final bool canSubmit;
  final bool canPreview;
  final bool isSubmitting;
  final bool isUploadingImage;
  final bool emoticonPanelOpen;
  final VoidCallback onPickImage;
  final VoidCallback onToggleEmoticon;
  final VoidCallback onPreview;
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
        duration: S1Motion.rapid,
        curve: S1Motion.standard,
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
                IconButton(
                  tooltip: '预览',
                  onPressed: canPreview && !busy ? onPreview : null,
                  icon: const Icon(Icons.visibility_outlined),
                ),
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
