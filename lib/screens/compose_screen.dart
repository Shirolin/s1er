import '../widgets/s1_ink_well.dart';
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/compose_draft.dart';
import '../models/compose_target.dart';
import '../models/post.dart';
import '../models/quote_info.dart';
import '../models/new_thread_form_info.dart';
import '../models/edit_post_form_info.dart';
import '../models/edit_post_submit_result.dart';
import '../models/private_message_item.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/compose_provider.dart';
import '../providers/compose_session_provider.dart';
import '../providers/forum_name_provider.dart';
import '../providers/image_cache_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_list_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/compact_label.dart';
import '../utils/author_color_adapter.dart';
import '../utils/compose_bbcode_wrap.dart';
import '../utils/compose_clipboard_image.dart';
import '../utils/compose_img_tags.dart';
import '../utils/compose_message_char_count.dart';
import '../utils/edit_post_message.dart';
import '../utils/platform_image_url.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/quote_builder.dart';
import '../utils/quote_snapshot_store.dart';
import '../utils/read_perm_options.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/window_size.dart';
import '../models/forum_attachment_upload_info.dart';
import '../models/compose_image_upload_result.dart';
import '../widgets/bbcode_renderer.dart';
import '../widgets/compose_bbcode_toolbar.dart';
import '../widgets/compose_emoticon_panel.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_draft_leave_dialog.dart';
import '../widgets/s1_adaptive_sheet.dart';
import '../widgets/s1_content_width.dart';
import '../widgets/web_avatar.dart';
import '../theme/s1_mouse_cursors.dart';

part 'compose/compose_preview_sheet.dart';
part 'compose/compose_meta_fields.dart';
part 'compose/compose_header.dart';
part 'compose/compose_message_field.dart';
part 'compose/compose_images.dart';
part 'compose/compose_bottom_bar.dart';

const _recentEmoticonsKey = 'compose_recent_emoticons';
const _maxBatchImages = 20;

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({
    super.key,
    this.tid,
    this.fid,
    this.quoteSnapshotId,
    this.reppost,
    this.subject,
    this.newThread = false,
    this.editPid,
    this.editPage,
    this.editIsFirst = false,
    this.editAttachImageUrls = const {},
  });

  final String? tid;
  final String? fid;

  /// 被引楼 [QuoteSnapshotStore] 内存 key，不是正文草稿。
  final String? quoteSnapshotId;
  final String? reppost;
  final String? subject;
  final bool newThread;
  final String? editPid;
  final int? editPage;
  final bool editIsFirst;

  /// 从读帖 HTML 带入的 `aid → URL`，与编辑表单解析结果合并。
  final Map<String, String> editAttachImageUrls;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeUploadedImage {
  const _ComposeUploadedImage({
    required this.tag,
    required this.label,
    this.previewUrl,
    this.slot,
  });

  /// 提交时写回的完整 BBCode。
  final String tag;
  final String label;

  /// `[img]` 外链或已解析的论坛附件图 URL；无则 Chip 只显示图标。
  final String? previewUrl;

  /// 编辑页占位 `⟦图N⟧` 的稳定编号；回复/新主题为 null。
  final int? slot;

  bool get hasThumb => previewUrl != null && previewUrl!.trim().isNotEmpty;

  bool get isAttachimg =>
      RegExp(r'^\[attachimg\]', caseSensitive: false).hasMatch(tag);

  bool get isForumAttach =>
      RegExp(r'^\[attach\]', caseSensitive: false).hasMatch(tag);
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _messageController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _subjectFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _redirectedToLogin = false;
  bool _allowPop = false;
  bool _showEmoticonPanel = false;
  double? _lastKeyboardHeight;
  QuoteSnapshot? _draft;
  bool _includeQuote = false;
  QuoteInfo? _quoteInfo;
  bool _quotePrefetching = false;
  String? _quotePrefetchError;
  final List<_ComposeUploadedImage> _uploadedImages = [];
  final Map<String, String> _imageLabelsByUrl = {};
  List<String> _recentEmoticons = [];
  late final ProviderSubscription<ComposeSession> _sessionSubscription;
  bool _suppressDraftSave = false;
  bool _suppressMediaSync = false;
  NewThreadFormInfo? _newThreadForm;
  bool _newThreadLoading = false;
  String? _selectedTypeId;
  String? _selectedReadPerm;
  EditPostFormInfo? _editForm;
  bool _editLoading = false;
  bool _editUncertain = false;
  bool _editConflict = false;
  bool _replyUncertain = false;

  /// 编辑页从服务器原文拆出的前置 `[quote]`（可移除，不进输入框）。
  String? _editLeadingQuote;

  /// 加载时拆出的正文基线（已去媒体标签；用于脏检查 / 草稿）。
  String _editLoadedBody = '';
  List<String> _editLoadedMediaTags = const [];
  bool _includeEditQuote = false;
  Map<String, String> _attachImageUrls = const {};
  ({Uint8List bytes, String filename})? _pendingUpload;
  final List<({Uint8List bytes, String filename})> _uploadQueue = [];
  int _uploadBatchTotal = 0;
  int _uploadBatchSuccess = 0;
  bool _uploadBatchActive = false;
  ComposeImageUploadSource _uploadSource = ComposeImageUploadSource.forum;
  bool _useOriginalResolution = false;
  bool _uploadOptionsExpanded = false;
  bool _preparingUpload = false;
  ForumAttachmentUploadInfo? _attachmentUploadInfo;

  bool get _hasValidTid => widget.tid != null && widget.tid!.isNotEmpty;
  bool get _isNewThread => widget.newThread;
  bool get _isEditing => widget.editPid != null && widget.editPid!.isNotEmpty;

  /// 编辑模式：媒体只走 Chip 条，不把长 `[img]` / `[attach]` 留在输入框。
  bool get _editMediaDetached => _isEditing;

  String? get _quotePid => widget.reppost ?? _draft?.post.pid;

  String? get _subjectLabel {
    final subject = widget.subject?.trim();
    if (subject == null || subject.isEmpty) return null;
    return subject;
  }

  String _forumDisplayName() {
    final fid = widget.fid;
    if (fid == null || fid.isEmpty) return '';
    return ref.read(forumNameProvider(fid)) ??
        ref.read(threadListProvider(fid)).asData?.value.forumName ??
        '版块 #$fid';
  }

  bool get _quoting => _includeQuote && _quoteInfo != null;

  bool get _editMediaChanged {
    if (_uploadedImages.length != _editLoadedMediaTags.length) return true;
    for (var i = 0; i < _uploadedImages.length; i++) {
      if (_uploadedImages[i].tag != _editLoadedMediaTags[i]) return true;
    }
    return false;
  }

  bool get _isDirty {
    if (_isEditing && _editForm != null) {
      final hadQuoteOnLoad =
          _editLeadingQuote != null && _editLeadingQuote!.trim().isNotEmpty;
      return _messageController.text != _editLoadedBody ||
          _subjectController.text != _editForm!.subject ||
          _selectedTypeId != _editForm!.selectedTypeId ||
          _selectedReadPerm != _editForm!.selectedReadPermission ||
          _includeEditQuote != hadQuoteOnLoad ||
          _editMediaChanged;
    }
    return _messageController.text.trim().isNotEmpty ||
        ((_isNewThread || _isEditing) &&
            _subjectController.text.trim().isNotEmpty) ||
        _uploadedImages.isNotEmpty;
  }

  bool get _canSubmit {
    final busy = _isSubmitting ||
        _isUploadingImage ||
        _preparingUpload ||
        _quotePrefetching ||
        _newThreadLoading ||
        _editLoading ||
        _editUncertain ||
        _editConflict ||
        _replyUncertain;
    if (busy) return false;
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasMedia = _uploadedImages.isNotEmpty;
    if (_isNewThread) {
      return _subjectController.text.trim().isNotEmpty && (hasText || hasMedia);
    }
    if (_isEditing) {
      final plain =
          stripComposeMediaPlaceholders(_messageController.text).trim();
      return _editForm != null && (plain.isNotEmpty || hasMedia);
    }
    return hasText || hasMedia || _quoting;
  }

  bool get _canPreview {
    if (_isEditing) {
      return _messageController.text.trim().isNotEmpty ||
          _uploadedImages.isNotEmpty ||
          _showingEditQuote;
    }
    return _messageController.text.trim().isNotEmpty ||
        _uploadedImages.isNotEmpty ||
        _quoting;
  }

  bool get _showingEditQuote =>
      _isEditing &&
      _includeEditQuote &&
      _editLeadingQuote != null &&
      _editLeadingQuote!.trim().isNotEmpty;

  List<String> get _currentMediaTags =>
      [for (final image in _uploadedImages) image.tag];

  List<int> get _currentMediaSlots => [
        for (final image in _uploadedImages) image.slot ?? 0,
      ];

  Map<int, String> get _currentMediaBySlot => {
        for (final image in _uploadedImages)
          if (image.slot != null && image.slot! > 0) image.slot!: image.tag,
      };

  /// 编辑：占位还原；回复/新主题：媒体仍接文末（回复图已 inline 在正文）。
  String _bodyWithMedia(String body) {
    if (_editMediaDetached) {
      return expandComposeMediaPlaceholders(body, _currentMediaBySlot);
    }
    return appendComposeMedia(body, _currentMediaTags);
  }

  /// 预览用正文：论坛 `[attachimg]` 换成可渲染的 `[img]url[/img]`。
  String _previewBodyWithMedia(String body) => rewriteAttachimgForPreview(
        _bodyWithMedia(body),
        _attachImageUrls,
      );

  int _nextEditMediaSlot() {
    var maxSlot = 0;
    for (final image in _uploadedImages) {
      final slot = image.slot ?? 0;
      if (slot > maxSlot) maxSlot = slot;
    }
    return maxSlot + 1;
  }

  void _mergeAttachImageUrls(Map<String, String> next) {
    if (next.isEmpty) return;
    _attachImageUrls = {..._attachImageUrls, ...next};
  }

  void _replaceUploadedImages(Iterable<_ComposeUploadedImage> next) {
    _uploadedImages
      ..clear()
      ..addAll(next);
  }

  void _applyEditMedia(
    List<ComposeMediaTag> media, {
    List<int>? slots,
  }) {
    _replaceUploadedImages([
      for (var i = 0; i < media.length; i++)
        _ComposeUploadedImage(
          tag: media[i].tag,
          label: media[i].label,
          previewUrl: media[i].previewUrl,
          slot: (slots != null && i < slots.length && slots[i] > 0)
              ? slots[i]
              : i + 1,
        ),
    ]);
    for (final item in media) {
      final url = item.previewUrl;
      if (url != null && url.isNotEmpty) {
        _imageLabelsByUrl[url] = item.label;
      }
    }
  }

  /// 正文占位为序：重排 Chip；删掉正文里已不存在的 slot。
  void _syncEditMediaFromBody() {
    if (!_editMediaDetached || _suppressMediaSync) return;
    final bySlot = <int, _ComposeUploadedImage>{
      for (final image in _uploadedImages)
        if (image.slot != null) image.slot!: image,
    };
    final ordered = <_ComposeUploadedImage>[];
    final seen = <int>{};
    for (final slot in extractComposeMediaPlaceholderSlots(
      _messageController.text,
    )) {
      if (seen.contains(slot)) continue;
      final image = bySlot[slot];
      if (image == null) continue;
      ordered.add(image);
      seen.add(slot);
    }
    final same = ordered.length == _uploadedImages.length &&
        List.generate(
          ordered.length,
          (i) =>
              ordered[i].slot == _uploadedImages[i].slot &&
              ordered[i].tag == _uploadedImages[i].tag,
        ).every((ok) => ok);
    if (same) return;
    setState(() => _replaceUploadedImages(ordered));
  }

  ComposeSession get _session => _sessionSubscription.read();

  ComposeTarget get _target {
    if (_isEditing) return EditPostTarget(pid: widget.editPid!);
    if (_isNewThread) return NewThreadTarget(fid: widget.fid ?? '');
    return ReplyTarget(tid: widget.tid ?? '', reppost: _quotePid);
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _subjectController.addListener(_onSubjectChanged);
    _messageFocusNode.addListener(_onMessageFocusChanged);
    _subjectFocusNode.addListener(_onMessageFocusChanged);
    if (widget.quoteSnapshotId != null) {
      _draft = QuoteSnapshotStore.peek(widget.quoteSnapshotId!);
    }
    final pid = _quotePid;
    _includeQuote = pid != null && pid.isNotEmpty;
    _sessionSubscription =
        ref.listenManual(composeSessionProvider(_target), (_, __) {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRecentEmoticons();
      // 仅回复模式恢复 compose_message_drafts；编辑/新主题绝不读该键。
      if (!_isEditing && !_isNewThread) {
        _restoreReplyDraft();
      }
      if (!ref.read(authStateProvider).isLoggedIn && !_redirectedToLogin) {
        _redirectedToLogin = true;
        // 勿 pop 再 push：会在 Web 上触发 disposed EngineFlutterView 断言刷屏
        context.push('/login');
        return;
      }
      if (_isNewThread) {
        _loadNewThreadForm();
      } else if (_isEditing) {
        _loadEditForm();
      } else {
        _prefetchOfficialQuote();
      }
      unawaited(_prefetchAttachmentUploadInfo());
    });
  }

  Future<void> _prefetchAttachmentUploadInfo({
    ForumAttachmentUploadInfo? seed,
  }) async {
    final fid = widget.fid;
    if (fid == null || fid.isEmpty) return;
    final info =
        await ref.read(composeControllerProvider).prefetchAttachmentUploadInfo(
              fid: fid,
              tid: widget.tid,
              editPid: widget.editPid,
              seed: seed,
            );
    if (!mounted || info == null) return;
    setState(() => _attachmentUploadInfo = info);
  }

  Future<void> _loadNewThreadForm() async {
    final fid = widget.fid;
    if (fid == null || fid.isEmpty) return;
    setState(() => _newThreadLoading = true);
    final form =
        await ref.read(composeControllerProvider).fetchNewThreadForm(fid: fid);
    if (!mounted) return;
    final saved = _session.restoreDraft();
    setState(() {
      _newThreadForm = form;
      _newThreadLoading = false;
      if (saved != null) {
        _suppressDraftSave = true;
        _subjectController.text = saved.subject;
        _messageController.text = saved.message;
        _selectedTypeId = saved.typeId;
        _suppressDraftSave = false;
      }
    });
    if (saved != null && mounted) {
      S1SnackBar.show(context, message: '已恢复草稿', bottomClearance: 72);
    }
  }

  Future<void> _loadEditForm() async {
    final fid = widget.fid;
    final tid = widget.tid;
    final pid = widget.editPid;
    if (fid == null ||
        fid.isEmpty ||
        tid == null ||
        tid.isEmpty ||
        pid == null) {
      return;
    }
    setState(() => _editLoading = true);
    final form = await ref.read(composeControllerProvider).fetchEditPostForm(
          fid: fid,
          tid: tid,
          pid: pid,
          isFirst: widget.editIsFirst,
        );
    if (!mounted) return;
    if (form.error != null) {
      setState(() {
        _editForm = form;
        _editLoading = false;
      });
      return;
    }
    final saved = _session.restoreDraft();
    final parts = EditPostMessageParts.split(form.message);
    _mergeAttachImageUrls(widget.editAttachImageUrls);
    _mergeAttachImageUrls(form.attachImageUrls);
    final mediaSplit = splitComposeMediaWithPlaceholders(
      parts.body,
      attachImageUrls: _attachImageUrls,
    );
    _suppressMediaSync = true;
    setState(() {
      _editForm = form;
      _editLoading = false;
      _selectedTypeId = form.selectedTypeId;
      _selectedReadPerm =
          normalizeSelectedReadPerm(form.selectedReadPermission);
      _subjectController.text = form.subject;
      _editLeadingQuote = parts.leadingQuote;
      _editLoadedBody = mediaSplit.body;
      _editLoadedMediaTags = [for (final m in mediaSplit.media) m.tag];
      _includeEditQuote = parts.hasLeadingQuote;
      _messageController.text = mediaSplit.body;
      _applyEditMedia(mediaSplit.media);
    });
    _suppressMediaSync = false;
    unawaited(
      _prefetchAttachmentUploadInfo(seed: form.attachmentUploadInfo),
    );
    if (saved != null && _editDraftDiffers(saved, form)) {
      final restore = await showS1ConfirmDialog(
        context,
        title: '使用本地草稿？',
        content: '本机有未提交的编辑，与服务器内容不同。',
        confirmLabel: '用本地草稿',
        cancelLabel: '用服务器内容',
      );
      if (!mounted) return;
      if (restore) {
        _suppressDraftSave = true;
        _suppressMediaSync = true;
        final draftParts = EditPostMessageParts.split(saved.message);
        // 草稿存的是可编辑正文（可含 ⟦图N⟧），不是整帖 raw。
        final draftBodyRaw =
            draftParts.hasLeadingQuote ? draftParts.body : saved.message;
        final draftMedia = _mediaFromDraft(
          saved.mediaTags,
          mediaSlots: saved.mediaSlots,
          fallbackBody: draftBodyRaw,
        );
        _subjectController.text = saved.subject;
        _messageController.text = draftMedia.body;
        _selectedTypeId = saved.typeId ?? form.selectedTypeId;
        _selectedReadPerm = normalizeSelectedReadPerm(
          saved.readPerm ?? form.selectedReadPermission,
        );
        final draftQuote = saved.leadingQuote;
        setState(() {
          if (draftQuote != null && draftQuote.trim().isNotEmpty) {
            _editLeadingQuote = draftQuote;
          } else if (draftParts.hasLeadingQuote) {
            _editLeadingQuote = draftParts.leadingQuote;
          }
          _includeEditQuote = saved.includeQuote ??
              (_editLeadingQuote != null &&
                  _editLeadingQuote!.trim().isNotEmpty);
          _applyEditMedia(draftMedia.media, slots: draftMedia.effectiveSlots);
        });
        _suppressMediaSync = false;
        _suppressDraftSave = false;
      } else {
        _session.clearDraft();
      }
    }
  }

  /// 草稿里的 `mediaTags` + 可选 `mediaSlots` + 正文（可含 `⟦图N⟧`）；旧草稿无占位时补上。
  ComposeMediaSplit _mediaFromDraft(
    List<String>? mediaTags, {
    List<int>? mediaSlots,
    required String fallbackBody,
  }) {
    if (mediaTags == null) {
      return splitComposeMediaWithPlaceholders(
        fallbackBody,
        attachImageUrls: _attachImageUrls,
      );
    }
    final media = <ComposeMediaTag>[];
    for (final item in mediaTags) {
      final tag = item.trim();
      if (tag.isEmpty) continue;
      final parsed = splitComposeMedia(
        tag,
        attachImageUrls: _attachImageUrls,
      ).media;
      if (parsed.isNotEmpty) {
        media.addAll(parsed);
      } else {
        media.add(ComposeMediaTag(tag: tag, label: '图片'));
      }
    }

    final slots = [...?mediaSlots];
    while (slots.length < media.length) {
      final next = slots.isEmpty
          ? 1
          : (slots.where((s) => s > 0).fold<int>(0, (a, b) => a > b ? a : b) +
              1);
      slots.add(next);
    }
    if (slots.length > media.length) {
      slots.removeRange(media.length, slots.length);
    }
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] < 1) slots[i] = i + 1;
    }

    // 去掉残留真实媒体 BBCode，保留已有 ⟦图N⟧。
    var body = splitComposeMedia(
      fallbackBody,
      attachImageUrls: _attachImageUrls,
    ).body;
    if (media.isNotEmpty && !composeMediaPlaceholderPattern.hasMatch(body)) {
      body = appendComposeMedia(
        body,
        [for (final slot in slots) composeMediaPlaceholder(slot)],
      );
    }
    return ComposeMediaSplit(
      body: body.trimRight(),
      media: media,
      slots: slots,
    );
  }

  bool _editDraftDiffers(ComposeDraft draft, EditPostFormInfo form) {
    final parts = EditPostMessageParts.split(form.message);
    final serverMedia = splitComposeMediaWithPlaceholders(
      parts.body,
      attachImageUrls: {
        ...widget.editAttachImageUrls,
        ...form.attachImageUrls,
      },
    );
    final draftParts = EditPostMessageParts.split(draft.message);
    final draftMedia = _mediaFromDraft(
      draft.mediaTags,
      mediaSlots: draft.mediaSlots,
      fallbackBody: draftParts.body,
    );
    final draftInclude = draft.includeQuote ?? draftParts.hasLeadingQuote;
    final mediaChanged = draftMedia.media.length != serverMedia.media.length ||
        List.generate(
          draftMedia.media.length,
          (i) => draftMedia.media[i].tag != serverMedia.media[i].tag,
        ).any((changed) => changed);
    return draftMedia.body != serverMedia.body ||
        mediaChanged ||
        draftInclude != parts.hasLeadingQuote ||
        draft.subject != form.subject ||
        draft.typeId != form.selectedTypeId ||
        draft.readPerm != form.selectedReadPermission;
  }

  void _saveDraft() {
    if (_suppressDraftSave) return;
    if (_isEditing) {
      _saveEditDraft();
      return;
    }
    _session.saveDraft(
      ComposeDraft(
        subject: _subjectController.text,
        message: _messageController.text,
        typeId: _selectedTypeId,
      ),
    );
  }

  void _saveEditDraft() {
    final form = _editForm;
    if (form == null) return;
    final hadQuoteOnLoad =
        _editLeadingQuote != null && _editLeadingQuote!.trim().isNotEmpty;
    final unchanged = _messageController.text == _editLoadedBody &&
        _subjectController.text == form.subject &&
        _selectedTypeId == form.selectedTypeId &&
        _selectedReadPerm == form.selectedReadPermission &&
        _includeEditQuote == hadQuoteOnLoad &&
        !_editMediaChanged;
    if (unchanged) {
      _session.clearDraft();
      return;
    }
    _session.saveDraft(
      ComposeDraft(
        subject: _subjectController.text,
        message: _messageController.text,
        typeId: _selectedTypeId,
        readPerm: _selectedReadPerm,
        leadingQuote: _editLeadingQuote,
        includeQuote: _includeEditQuote,
        mediaTags: _currentMediaTags,
        mediaSlots: _currentMediaSlots,
      ),
    );
  }

  Future<void> _openThreadSettingsSheet() async {
    if (!mounted) return;

    final Map<String, String> threadTypes;
    final Map<String, String> readPermissions;
    final bool allowUncategorized;
    final bool typeRequired;

    if (_isNewThread) {
      final form = _newThreadForm;
      if (form == null || form.error != null) return;
      threadTypes = form.threadTypes;
      readPermissions = const {};
      allowUncategorized = !form.typeRequired;
      typeRequired = form.typeRequired;
    } else if (_isEditing) {
      final form = _editForm;
      if (form == null || form.error != null) return;
      threadTypes = form.threadTypes;
      readPermissions = form.readPermissions;
      allowUncategorized = true;
      typeRequired = false;
    } else {
      return;
    }

    if (threadTypes.isEmpty && readPermissions.isEmpty) return;

    await showS1FormSheet<void>(
      context: context,
      builder: (sheetContext) {
        return S1AdaptiveSheetScaffold(
          title: '主题设置',
          children: [
            _ComposeThreadMetaFields(
              threadTypes: threadTypes,
              readPermissions: readPermissions,
              selectedTypeId: _selectedTypeId,
              selectedReadPerm: _selectedReadPerm,
              allowUncategorized: allowUncategorized,
              onTypeChanged: (value) {
                setState(() {
                  _selectedTypeId = value;
                  _saveDraft();
                });
              },
              onReadPermChanged: (value) {
                setState(() {
                  _selectedReadPerm = value;
                  _saveDraft();
                });
              },
            ),
            if (typeRequired) ...[
              const SizedBox(height: 8),
              Text(
                '本版块必须选择主题分类',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
    );
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

  void _restoreReplyDraft() {
    final saved = _session.restoreDraft()?.message;
    if (saved == null) return;
    _suppressDraftSave = true;
    _messageController.value = TextEditingValue(
      text: saved,
      selection: TextSelection.collapsed(offset: saved.length),
    );
    _suppressDraftSave = false;
    S1SnackBar.show(context, message: '已恢复草稿', bottomClearance: 72);
  }

  void _onMessageChanged() {
    if (!mounted) return;
    if (!_suppressMediaSync && !_editMediaDetached) {
      final split = splitComposeMedia(
        _messageController.text,
        attachImageUrls: _attachImageUrls,
      );
      final next = <_ComposeUploadedImage>[
        for (final m in split.media)
          _ComposeUploadedImage(
            tag: m.tag,
            label: m.isAttachimg
                ? m.label
                : (_imageLabelsByUrl[m.previewUrl ?? ''] ?? m.label),
            previewUrl: m.previewUrl,
          ),
      ];
      setState(() {
        _replaceUploadedImages(next);
      });
    } else if (_editMediaDetached) {
      _syncEditMediaFromBody();
      if (mounted) setState(() {});
    } else if (mounted) {
      setState(() {});
    }
    _saveDraft();
  }

  void _onSubjectChanged() {
    _saveDraft();
    if (mounted) setState(() {});
  }

  void _onMessageFocusChanged() {
    if (mounted) setState(() {});
  }

  void _expandTitleField() {
    _messageFocusNode.unfocus();
    _subjectFocusNode.requestFocus();
  }

  bool _collapseComposeTitle(BuildContext context) {
    return !context.isExpandedOrAbove &&
        _messageFocusNode.hasFocus &&
        !_subjectFocusNode.hasFocus;
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
        _quotePrefetchError = '引文加载失败，仍可直接输入回复';
      }
    });
  }

  String get _title {
    if (_isNewThread) return '发新主题';
    if (_isEditing) return widget.editIsFirst ? '编辑主题' : '编辑回复';
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
    final start =
        selection.isValid ? selection.start : _messageController.text.length;
    final end =
        selection.isValid ? selection.end : _messageController.text.length;
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

  bool get _composeBusy =>
      _isSubmitting ||
      _isUploadingImage ||
      _quotePrefetching ||
      _newThreadLoading ||
      _editLoading ||
      _editUncertain ||
      _editConflict ||
      _replyUncertain;

  void _applyBbcodeWrap(String openTag, String closeTag) {
    if (_composeBusy) return;
    final selection = _messageController.selection;
    final start =
        selection.isValid ? selection.start : _messageController.text.length;
    final end =
        selection.isValid ? selection.end : _messageController.text.length;
    final result = wrapBbcodeSelection(
      text: _messageController.text,
      start: start,
      end: end,
      openTag: openTag,
      closeTag: closeTag,
    );
    _messageController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    _messageFocusNode.requestFocus();
  }

  Future<void> _insertUrlBbcode() async {
    if (_composeBusy || !mounted) return;
    if (_showEmoticonPanel) {
      setState(() => _showEmoticonPanel = false);
    }
    _messageFocusNode.unfocus();

    final selection = _messageController.selection;
    final start =
        selection.isValid ? selection.start : _messageController.text.length;
    final end =
        selection.isValid ? selection.end : _messageController.text.length;

    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('插入链接'),
          content: TextField(
            controller: urlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://',
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isEmpty) return;
              Navigator.of(ctx).pop(trimmed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = urlController.text.trim();
                if (trimmed.isEmpty) return;
                Navigator.of(ctx).pop(trimmed);
              },
              child: const Text('插入'),
            ),
          ],
        );
      },
    );
    urlController.dispose();
    if (!mounted || url == null || url.isEmpty) {
      _messageFocusNode.requestFocus();
      return;
    }

    final result = wrapBbcodeSelection(
      text: _messageController.text,
      start: start,
      end: end,
      openTag: '[url=$url]',
      closeTag: '[/url]',
    );
    _messageController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    _messageFocusNode.requestFocus();
  }

  void _applyBbcodeColor(String cssColor) {
    final color = AuthorColorAdapter.parseCssColor(cssColor);
    if (color == null) return;
    final hex = AuthorColorAdapter.toCssHex(color);
    _applyBbcodeWrap('[color=$hex]', '[/color]');
  }

  Future<void> _insertCreditHide() async {
    if (_composeBusy || !mounted) return;
    if (_showEmoticonPanel) {
      setState(() => _showEmoticonPanel = false);
    }
    _messageFocusNode.unfocus();

    final selection = _messageController.selection;
    final start =
        selection.isValid ? selection.start : _messageController.text.length;
    final end =
        selection.isValid ? selection.end : _messageController.text.length;

    final creditController = TextEditingController();
    final credits = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('积分隐藏'),
          content: TextField(
            controller: creditController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '所需积分',
              hintText: '例如 10',
            ),
            onSubmitted: (value) {
              final n = int.tryParse(value.trim());
              if (n == null || n < 1) return;
              Navigator.of(ctx).pop(n);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(creditController.text.trim());
                if (n == null || n < 1) return;
                Navigator.of(ctx).pop(n);
              },
              child: const Text('插入'),
            ),
          ],
        );
      },
    );
    creditController.dispose();
    if (!mounted || credits == null) {
      _messageFocusNode.requestFocus();
      return;
    }

    final result = wrapBbcodeSelection(
      text: _messageController.text,
      start: start,
      end: end,
      openTag: '[hide=$credits]',
      closeTag: '[/hide]',
    );
    _messageController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    _messageFocusNode.requestFocus();
  }

  void _dismissEmoticonPanelForShortcut() {
    if (!_showEmoticonPanel) return;
    setState(() => _showEmoticonPanel = false);
    _messageFocusNode.requestFocus();
  }

  Future<void> _showPreview() async {
    final message = _messageController.text;
    if (!_canPreview) return;
    _messageFocusNode.unfocus();
    if (_showEmoticonPanel) {
      setState(() => _showEmoticonPanel = false);
    }
    final QuoteInfo? quoteInfo;
    final String previewBbcode;
    final tid = widget.tid;
    if (_isEditing) {
      final parts = EditPostMessageParts(
        leadingQuote: _showingEditQuote ? _editLeadingQuote : null,
        body: message,
      );
      quoteInfo = parts.hasLeadingQuote
          ? QuoteInfo(
              noticeAuthor: '',
              noticeTrimStr: parts.leadingQuote!,
            )
          : null;
      previewBbcode = await ref
          .read(composeControllerProvider)
          .applySignature(_previewBodyWithMedia(message));
    } else {
      // 回复/新帖：正文里已 inline `[attachimg]`，勿再 appendComposeMedia（会重复）。
      // 预览需改写成 `[img]url[/img]`，否则 BbcodeRenderer 看不到图。
      quoteInfo = _quoting ? _quoteInfo : null;
      previewBbcode = await ref.read(composeControllerProvider).applySignature(
            rewriteAttachimgForPreview(message, _attachImageUrls),
          );
    }
    if (!mounted) return;

    final previewSubject = _isNewThread
        ? _subjectController.text.trim()
        : (_isEditing && widget.editIsFirst
            ? _subjectController.text.trim()
            : (_subjectLabel?.trim() ?? ''));
    final auth = ref.read(authStateProvider);
    final authorName = auth.user?.username ?? auth.username ?? '我';
    final authorAvatar = User.resolveAvatarUrl(
          auth.user?.avatar,
          size: 'middle',
        ) ??
        PrivateMessageItem.avatarUrlForUid(auth.user?.uid ?? '');

    final confirmed = await showS1FormSheet<bool>(
      context: context,
      desktopMaxWidth: S1Breakpoints.contentWidthReading,
      builder: (ctx) => _ComposePreviewSheet(
        subject: previewSubject.isEmpty ? null : previewSubject,
        isNewThread: _isNewThread,
        isEditing: _isEditing,
        quoteInfo: quoteInfo,
        previewBbcode: previewBbcode,
        tid: tid,
        authorName: authorName,
        authorAvatar: authorAvatar,
        attachPreviewLimited: hasUnresolvedAttachimg(previewBbcode),
        canSubmit: _canSubmit,
        submitLabel: _isEditing ? '确认保存' : '确认发送',
      ),
    );
    if (confirmed == true && mounted) {
      await _submit(fromPreview: true);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _subjectController.removeListener(_onSubjectChanged);
    _messageFocusNode.removeListener(_onMessageFocusChanged);
    _subjectFocusNode.removeListener(_onMessageFocusChanged);
    _messageController.dispose();
    _subjectController.dispose();
    _messageFocusNode.dispose();
    _subjectFocusNode.dispose();
    super.dispose();
  }

  void _removeUploadedImage(_ComposeUploadedImage image) {
    if (_editMediaDetached) {
      final slot = image.slot;
      _suppressMediaSync = true;
      if (slot != null) {
        final next = removeComposeMediaPlaceholder(
          _messageController.text,
          slot,
        );
        _messageController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(
            offset: next.length.clamp(0, next.length),
          ),
        );
      }
      setState(() {
        _uploadedImages.removeWhere(
          (item) =>
              identical(item, image) ||
              (item.slot != null && item.slot == image.slot),
        );
      });
      _suppressMediaSync = false;
      final url = image.previewUrl;
      if (url != null) _imageLabelsByUrl.remove(url);
      _saveDraft();
      return;
    }
    final url = image.previewUrl;
    var next = _messageController.text;
    if (image.tag.trim().isNotEmpty) {
      next = removeMediaTag(next, image.tag);
    } else if (url != null && url.isNotEmpty) {
      next = removeImgTag(next, url);
    }
    if (url != null) _imageLabelsByUrl.remove(url);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: next.length.clamp(0, next.length),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_isSubmitting) return;

    // iOS 的 file_selector 只认 uniformTypeIdentifiers，仅传 extensions 会抛
    // ArgumentError；extensions 保留给 Android / 桌面端过滤用。
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
      uniformTypeIdentifiers: <String>['public.image'],
    );
    final List<XFile> files;
    try {
      files = await openFiles(acceptedTypeGroups: [typeGroup]);
    } on Object catch (e) {
      if (mounted) {
        S1SnackBar.error(context, message: '选择图片失败：$e');
      }
      return;
    }
    if (files.isEmpty) return;

    final items = <({Uint8List bytes, String filename})>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      items.add((bytes: bytes, filename: file.name));
    }
    if (!mounted) return;
    _enqueueImages(items);
  }

  int get _inflightImageCount =>
      _uploadQueue.length + (_pendingUpload != null ? 1 : 0);

  void _enqueueImages(List<({Uint8List bytes, String filename})> items) {
    if (_isSubmitting || items.isEmpty) return;

    final maxBytes =
        ref.read(composeControllerProvider).imageUploadMaxBytes(_uploadSource);
    final oversize = <String>[];
    final accepted = <({Uint8List bytes, String filename})>[];
    var truncated = false;

    for (final item in items) {
      if (item.bytes.isEmpty) continue;
      if (item.bytes.length > maxBytes) {
        oversize.add(
          item.filename.trim().isEmpty ? '图片' : item.filename.trim(),
        );
        continue;
      }
      if (_inflightImageCount + accepted.length >= _maxBatchImages) {
        truncated = true;
        break;
      }
      accepted.add(item);
    }

    if (oversize.isNotEmpty && mounted) {
      final mb = maxBytes ~/ (1024 * 1024);
      S1SnackBar.show(
        context,
        message: oversize.length == 1
            ? '${oversize.first} 超过 ${mb}MB，已跳过'
            : '${oversize.length} 张图片超过 ${mb}MB，已跳过',
        bottomClearance: 72,
      );
    }
    if (truncated && mounted) {
      S1SnackBar.show(
        context,
        message: '一次最多 $_maxBatchImages 张图片',
        bottomClearance: 72,
      );
    }
    if (accepted.isEmpty) return;

    setState(() {
      if (!_uploadBatchActive) {
        _uploadBatchActive = true;
        _uploadBatchTotal = accepted.length;
        _uploadBatchSuccess = 0;
      } else {
        _uploadBatchTotal += accepted.length;
      }
      _uploadQueue.addAll(accepted);
    });
    unawaited(_drainUploadQueue());
  }

  Future<void> _drainUploadQueue() async {
    if (_isUploadingImage || _isSubmitting || _preparingUpload) return;

    while (mounted && !_isSubmitting) {
      if (_pendingUpload == null) {
        if (_uploadQueue.isEmpty) break;
        setState(() => _pendingUpload = _uploadQueue.removeAt(0));
      }

      final pending = _pendingUpload;
      if (pending == null) break;

      final fid = widget.fid;
      if (fid == null || fid.isEmpty) {
        setState(() {
          _pendingUpload = null;
          _isUploadingImage = false;
        });
        if (mounted) {
          S1SnackBar.show(
            context,
            message: '缺少版块信息，无法上传图片',
            bottomClearance: 72,
          );
        }
        break;
      }

      if (_uploadSource == ComposeImageUploadSource.forum &&
          (_attachmentUploadInfo == null || !_attachmentUploadInfo!.isValid)) {
        setState(() => _preparingUpload = true);
        await _prefetchAttachmentUploadInfo();
        if (!mounted) return;
        setState(() => _preparingUpload = false);
        if (_attachmentUploadInfo == null || !_attachmentUploadInfo!.isValid) {
          setState(() => _isUploadingImage = false);
          if (mounted) {
            S1SnackBar.error(
              context,
              message: '无法准备论坛上传，请稍后重试或改用外链',
              actionLabel: '改用外链',
              onAction: () {
                if (!mounted) return;
                setState(() {
                  _uploadSource = ComposeImageUploadSource.external;
                });
                // 保留 _pendingUpload，改用外链后继续传同一张。
                unawaited(_drainUploadQueue());
              },
            );
          }
          break;
        }
      }

      setState(() => _isUploadingImage = true);
      var failed = false;
      try {
        final result = await ref.read(composeControllerProvider).uploadImage(
              bytes: pending.bytes,
              filename: pending.filename,
              fid: fid,
              tid: widget.tid,
              editPid: widget.editPid,
              source: _uploadSource,
              useOriginalResolution: _useOriginalResolution,
              seedUploadInfo: _attachmentUploadInfo,
            );
        if (!mounted) return;
        _insertUploadedImage(result: result);
        setState(() {
          _pendingUpload = null;
          _uploadBatchSuccess += 1;
        });
      } catch (e) {
        failed = true;
        if (mounted) {
          setState(() => _isUploadingImage = false);
          S1SnackBar.error(
            context,
            message: e.toString(),
            actionLabel:
                _uploadSource == ComposeImageUploadSource.forum ? '改用外链' : '重试',
            onAction: () {
              if (!mounted) return;
              if (_uploadSource == ComposeImageUploadSource.forum) {
                setState(() {
                  _uploadSource = ComposeImageUploadSource.external;
                });
              }
              // 失败项仍在 _pendingUpload，切换/重试后继续。
              unawaited(_drainUploadQueue());
            },
          );
        }
        break;
      } finally {
        if (mounted && !failed) {
          setState(() => _isUploadingImage = false);
        }
      }
    }

    if (!mounted) return;
    if (_pendingUpload != null) return;

    if (_uploadBatchActive && _uploadQueue.isEmpty && !_isUploadingImage) {
      final n = _uploadBatchSuccess;
      setState(() {
        _uploadBatchActive = false;
        _uploadBatchTotal = 0;
        _uploadBatchSuccess = 0;
      });
      if (n > 0) {
        S1SnackBar.show(
          context,
          message: n == 1 ? '图片已添加' : '已添加 $n 张图片',
          bottomClearance: 72,
        );
      }
    }
  }

  void _insertUploadedImage({
    required ComposeImageUploadResult result,
  }) {
    final label = result.label.trim().isEmpty ? '图片' : result.label.trim();
    final preview = result.previewUrl?.trim();
    if (preview != null && preview.isNotEmpty) {
      _imageLabelsByUrl[preview] = label;
    }
    if (result.aid != null &&
        result.aid!.isNotEmpty &&
        preview != null &&
        preview.isNotEmpty) {
      _mergeAttachImageUrls({result.aid!: preview});
    }

    if (_editMediaDetached) {
      final slot = _nextEditMediaSlot();
      final selection = _messageController.selection;
      final start =
          selection.isValid ? selection.start : _messageController.text.length;
      final end =
          selection.isValid ? selection.end : _messageController.text.length;
      final inserted = insertComposeMediaPlaceholderAt(
        text: _messageController.text,
        start: start,
        end: end,
        slot: slot,
      );
      _suppressMediaSync = true;
      _messageController.value = TextEditingValue(
        text: inserted.text,
        selection: TextSelection.collapsed(offset: inserted.cursor),
      );
      _uploadedImages.add(
        _ComposeUploadedImage(
          tag: result.insertTag,
          label: label,
          previewUrl: preview,
          slot: slot,
        ),
      );
      _suppressMediaSync = false;
      _saveDraft();
    } else {
      final selection = _messageController.selection;
      final start =
          selection.isValid ? selection.start : _messageController.text.length;
      final end =
          selection.isValid ? selection.end : _messageController.text.length;
      final inserted = insertMediaTagAt(
        text: _messageController.text,
        start: start,
        end: end,
        tag: result.insertTag,
      );
      _messageController.value = TextEditingValue(
        text: inserted.text,
        selection: TextSelection.collapsed(offset: inserted.cursor),
      );
    }
  }

  Future<void> _pasteIntoMessage() async {
    if (_isSubmitting) return;
    final bytes = await readComposeClipboardImage();
    if (bytes != null && bytes.isNotEmpty) {
      _enqueueImages([
        (bytes: bytes, filename: composeClipboardImageFilename()),
      ]);
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final selection = _messageController.selection;
    final start =
        selection.isValid ? selection.start : _messageController.text.length;
    final end =
        selection.isValid ? selection.end : _messageController.text.length;
    final next = _messageController.text.replaceRange(start, end, text);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> _submit({bool fromPreview = false}) async {
    if ((!_isNewThread && !_hasValidTid) ||
        widget.fid == null ||
        widget.fid!.isEmpty) {
      S1SnackBar.show(
        context,
        message: _isNewThread ? '缺少版块信息，请返回重试' : '缺少主题信息，请返回重试',
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
    if (_isNewThread) {
      final subject = _subjectController.text.trim();
      final form = _newThreadForm;
      if (subject.isEmpty || userText.isEmpty) {
        S1SnackBar.show(context, message: '请输入标题和正文', bottomClearance: 72);
        return;
      }
      if (form == null || _newThreadLoading) {
        S1SnackBar.show(context, message: '发帖表单仍在加载，请稍候', bottomClearance: 72);
        return;
      }
      if (form.error != null) {
        S1SnackBar.show(context, message: form.error!, bottomClearance: 72);
        return;
      }
      if (form.typeRequired &&
          (_selectedTypeId == null || _selectedTypeId!.isEmpty)) {
        S1SnackBar.show(context, message: '请选择主题分类', bottomClearance: 72);
        if (!context.isExpandedOrAbove) {
          await _openThreadSettingsSheet();
        }
        return;
      }
      if (!fromPreview) {
        final confirmed = await showS1ConfirmDialog(
          context,
          title: '确认发布主题？',
          content: '版块：${_forumDisplayName()}\n标题：$subject\n发布后将对其他用户可见。',
          confirmLabel: '发布',
        );
        if (!mounted || !confirmed) return;
      }
      S1Haptics.medium();
      setState(() => _isSubmitting = true);
      try {
        final result =
            await ref.read(composeControllerProvider).submitNewThread(
                  fid: widget.fid!,
                  subject: subject,
                  message: userText,
                  typeId: _selectedTypeId,
                );
        if (!mounted) return;
        if (result.isSuccess) {
          _session.clearDraft();
          _allowPopAndExit(result);
        } else {
          S1SnackBar.error(
            context,
            message: result.error ?? '发帖失败',
            bottomClearance: 72,
          );
        }
      } catch (e) {
        if (mounted) {
          S1SnackBar.error(context, message: '$e', bottomClearance: 72);
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }
    if (_isEditing) {
      final form = _editForm;
      final pid = widget.editPid;
      if (form == null || _editLoading) {
        S1SnackBar.show(context, message: '编辑表单仍在加载，请稍候', bottomClearance: 72);
        return;
      }
      if (form.error != null || !form.canEdit || pid == null) {
        S1SnackBar.show(
          context,
          message: form.error ?? '当前帖子不可编辑',
          bottomClearance: 72,
        );
        return;
      }
      if (widget.editIsFirst && _subjectController.text.trim().isEmpty) {
        S1SnackBar.show(context, message: '请输入标题', bottomClearance: 72);
        return;
      }
      if (stripComposeMediaPlaceholders(userText).trim().isEmpty &&
          _uploadedImages.isEmpty) {
        S1SnackBar.show(context, message: '请输入正文', bottomClearance: 72);
        return;
      }
      if (!fromPreview) {
        final confirmed = await showS1ConfirmDialog(
          context,
          title: '确认覆盖帖子内容？',
          content: widget.editIsFirst
              ? '标题：${_subjectController.text.trim()}\n提交后将覆盖服务器上的主题内容。'
              : '提交后将覆盖服务器上的回复内容。',
          confirmLabel: '确认编辑',
        );
        if (!mounted || !confirmed) return;
      }
      S1Haptics.medium();
      setState(() => _isSubmitting = true);
      try {
        final composed = EditPostMessageParts.compose(
          leadingQuote: _showingEditQuote ? _editLeadingQuote : null,
          body: _bodyWithMedia(userText),
        );
        final result = await ref.read(composeControllerProvider).submitEditPost(
              fid: widget.fid!,
              tid: widget.tid!,
              pid: pid,
              isFirst: widget.editIsFirst,
              subject: _subjectController.text,
              message: composed,
              typeId: _selectedTypeId,
              readPerm: _selectedReadPerm,
              baseline: form,
            );
        if (!mounted) return;
        if (result.isSuccess) {
          _session.clearDraft();
          _allowPopAndExit(result);
        } else if (result.isConflict) {
          setState(() => _editConflict = true);
          S1SnackBar.error(
            context,
            message: result.message ?? '服务器内容已变化，请重新载入',
            bottomClearance: 72,
          );
        } else if (result.isUncertain) {
          setState(() => _editUncertain = true);
          S1SnackBar.error(
            context,
            message: result.message ?? '编辑状态不确定，请先核对服务器内容',
            bottomClearance: 72,
          );
        } else {
          S1SnackBar.error(
            context,
            message: result.message ?? '编辑失败',
            bottomClearance: 72,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _editUncertain = true);
          S1SnackBar.error(context, message: '$e', bottomClearance: 72);
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }
    final quoting = _quoting;
    if (userText.isEmpty && !quoting) {
      S1SnackBar.show(context, message: '请输入回复', bottomClearance: 72);
      return;
    }

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

    S1Haptics.medium();
    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(composeControllerProvider).submitReply(
            tid: widget.tid!,
            fid: widget.fid!,
            message: userText,
            quoteInfo: quoting ? _quoteInfo : null,
            quotedPost: quoting ? _draft?.post : null,
          );

      if (mounted) {
        if (result.isSuccess) {
          final snapshotId = widget.quoteSnapshotId;
          if (snapshotId != null) QuoteSnapshotStore.remove(snapshotId);
          _session.clearDraft();
          setState(() => _replyUncertain = false);
          S1SnackBar.show(
            context,
            message: '回复成功',
            bottomClearance: 16,
            feedback: S1SnackBarFeedback.success,
          );
          _allowPopAndExit(result);
        } else if (result.isUncertain) {
          setState(() => _replyUncertain = true);
          S1SnackBar.show(
            context,
            message: result.message ?? '回复状态不明确，请返回主题刷新确认后再决定是否重发',
            bottomClearance: 72,
          );
        } else {
          S1SnackBar.error(
            context,
            message: result.message ?? result.error ?? '回复失败',
            bottomClearance: 72,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _replyUncertain = true);
        S1SnackBar.show(
          context,
          message: '回复状态不明确，请返回主题刷新确认后再决定是否重发',
          bottomClearance: 72,
        );
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

  void _removeEditQuote() {
    setState(() => _includeEditQuote = false);
    _saveDraft();
  }

  Future<void> _recheckEditState() async {
    if (!_isEditing ||
        widget.fid == null ||
        widget.tid == null ||
        widget.editPid == null) {
      return;
    }
    setState(() => _editLoading = true);
    final latest = await ref.read(composeControllerProvider).fetchEditPostForm(
          fid: widget.fid!,
          tid: widget.tid!,
          pid: widget.editPid!,
          isFirst: widget.editIsFirst,
        );
    if (!mounted) return;
    final desiredCore = EditPostMessageParts.compose(
      leadingQuote: _showingEditQuote ? _editLeadingQuote : null,
      body: _bodyWithMedia(_messageController.text),
    );
    final latestParts = EditPostMessageParts.split(latest.message);
    _mergeAttachImageUrls(latest.attachImageUrls);
    final latestCore = EditPostMessageParts.compose(
      leadingQuote: latestParts.leadingQuote,
      body: latestParts.body,
    );
    final matchesDesired = desiredCore.trim() == latestCore.trim() &&
        (!widget.editIsFirst ||
            latest.subject.trim() == _subjectController.text.trim());
    if (matchesDesired) {
      _session.clearDraft();
      setState(() => _editLoading = false);
      _allowPopAndExit(
        const EditPostSubmitResult.success(message: '编辑成功'),
      );
      return;
    }
    final baseline = _editForm;
    final matchesBaseline = baseline != null &&
        latest.message == baseline.message &&
        latest.subject == baseline.subject &&
        latest.selectedTypeId == baseline.selectedTypeId &&
        latest.selectedReadPermission == baseline.selectedReadPermission;
    setState(() {
      _editLoading = false;
      _editUncertain = false;
      _editConflict = !matchesBaseline;
      if (matchesBaseline) _editForm = latest;
    });
    S1SnackBar.show(
      context,
      message:
          matchesBaseline ? '服务器内容仍未变化，可以重新确认提交' : '服务器内容与当前编辑不同，请重新载入后再编辑',
      bottomClearance: 72,
    );
  }

  /// 先放开 [PopScope.canPop]，再在下一帧退出。
  ///
  /// 同帧 `setState(_allowPop=true)` + `pop` 时 canPop 仍是旧值，弹出会被拦下；
  /// 而 [_handlePop] 见 `_allowPop` 已为 true 会直接 return，页面就卡住。
  ///
  /// 正式路由走 [GoRouter.push]，必须用 [GoRouter.pop] 才能把结果交回等待方；
  /// Widget 测试若只有 [MaterialApp]/[Navigator] 则回退 [Navigator.pop]。
  void _allowPopAndExit([Object? result]) {
    _allowPop = true;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 再等一帧，确保 PopScope.canPop 已随本帧重建生效。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _popComposeRoute(result);
      });
    });
  }

  void _popComposeRoute([Object? result]) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop(result);
        return;
      }
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop) return;
    if (_allowPop) {
      // 与 [_allowPopAndExit] 同竞态：允许后重试一次。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _popComposeRoute(result);
      });
      return;
    }
    if (!_isDirty) return;

    final title = _isNewThread ? '离开发帖？' : (_isEditing ? '离开编辑？' : '离开回复？');
    final choice = await showS1DraftLeaveDialog(
      context,
      title: title,
      content: '未发送内容仅保存在本机。放弃后不可恢复。',
    );
    if (!mounted) return;
    switch (choice) {
      case S1DraftLeaveChoice.stay:
        return;
      case S1DraftLeaveChoice.keepAndLeave:
        _saveDraft();
        break;
      case S1DraftLeaveChoice.discardAndLeave:
        _session.clearDraft();
        break;
    }
    _allowPopAndExit();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = _isSubmitting ||
        _isUploadingImage ||
        _preparingUpload ||
        _quotePrefetching ||
        _newThreadLoading ||
        _editLoading ||
        _editUncertain ||
        _editConflict ||
        _replyUncertain;
    // 回复编辑与回复页一致展示主题；一楼编辑已有可改标题控件，不再叠一行。
    final subject = (_isEditing && widget.editIsFirst) ? null : _subjectLabel;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 0) {
      _lastKeyboardHeight = keyboardInset;
    }
    final showPanel = _showEmoticonPanel && keyboardInset <= 0;
    final fid = widget.fid;
    final forumName = fid == null || fid.isEmpty
        ? null
        : (ref.watch(forumNameProvider(fid)) ??
            ref.watch(threadListProvider(fid)).asData?.value.forumName);

    if (!_isNewThread && !_hasValidTid) {
      return Scaffold(
        backgroundColor: S1Surface.page(scheme),
        appBar: AppBar(
          elevation: 0,
          title: Text('无法回复', style: textTheme.titleLarge),
        ),
        body: S1ContentWidth(
          mode: S1ContentWidthMode.form,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '暂不支持从此处回复，请先进入主题页。',
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final formColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isNewThread)
          _NewThreadHeader(
            form: _newThreadForm,
            controller: _subjectController,
            selectedTypeId: _selectedTypeId,
            collapseTitle: _collapseComposeTitle(context),
            subjectFocusNode: _subjectFocusNode,
            onExpandTitle: _expandTitleField,
            onTypeChanged: (value) {
              setState(() {
                _selectedTypeId = value;
                _saveDraft();
              });
            },
            onOpenThreadSettings: _openThreadSettingsSheet,
          ),
        if (_isEditing)
          _EditPostHeader(
            form: _editForm,
            controller: _subjectController,
            selectedTypeId: _selectedTypeId,
            selectedReadPerm: _selectedReadPerm,
            collapseTitle: _collapseComposeTitle(context),
            subjectFocusNode: _subjectFocusNode,
            onExpandTitle: _expandTitleField,
            onTypeChanged: (value) {
              setState(() {
                _selectedTypeId = value;
                _saveDraft();
              });
            },
            onReadPermChanged: (value) {
              setState(() {
                _selectedReadPerm = value;
                _saveDraft();
              });
            },
            onOpenThreadSettings: _openThreadSettingsSheet,
          ),
        if (_isEditing && (_editUncertain || _editConflict))
          _EditPostStatus(
            message:
                _editUncertain ? '编辑结果不确定，请先核对服务器内容。' : '服务器内容已变化，请重新载入后再编辑。',
            actionLabel: '核对服务器',
            onPressed: _recheckEditState,
          ),
        if (!_isNewThread && !_isEditing && _replyUncertain)
          _EditPostStatus(
            message: '回复状态不明确，请返回主题刷新确认后再决定是否重发。',
            actionLabel: '知道了',
            onPressed: () => setState(() => _replyUncertain = false),
          ),
        if (_includeQuote && !_isNewThread && !_isEditing)
          _ComposeQuoteBanner(
            post: _draft?.post,
            displayFloor: _draft?.displayFloor ?? 0,
            onRemove: _removeQuote,
            loading: _quotePrefetching,
            error: _quotePrefetchError,
          ),
        if (_showingEditQuote) ...[
          Builder(
            builder: (context) {
              final parsed = QuoteBuilder.parseClientQuote(_editLeadingQuote!);
              final author = parsed.author;
              return _ComposeQuoteBanner(
                title: (author != null && author.isNotEmpty)
                    ? '引用 · $author'
                    : '引用楼层',
                preview: parsed.preview,
                onRemove: _removeEditQuote,
              );
            },
          ),
        ],
        if (subject != null && !_isNewThread)
          _ComposeSubjectLine(subject: subject),
        if (_uploadedImages.isNotEmpty) ...[
          _ComposeImageStrip(
            images: List.unmodifiable(_uploadedImages),
            onRemove: _removeUploadedImage,
          ),
          if (_uploadedImages.any((image) => !image.hasThumb))
            const _ComposeMediaPreviewHint(),
        ],
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                  () => unawaited(_pasteIntoMessage()),
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
                  unawaited(_pasteIntoMessage()),
            },
            child: _ComposeMessageField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              hintText: _isNewThread
                  ? '输入主题内容…'
                  : (_isEditing ? '输入编辑后的内容…' : '输入回复内容…'),
              onTap: () {
                if (_showEmoticonPanel) {
                  setState(() => _showEmoticonPanel = false);
                }
              },
            ),
          ),
        ),
        ClipRect(
          child: AnimatedAlign(
            duration: S1Motion.medium,
            curve: S1Motion.standard,
            heightFactor: showPanel ? 1 : 0,
            alignment: Alignment.bottomCenter,
            child: ComposeEmoticonPanel(
              onSelect: _insertEmoticon,
              recent: _recentEmoticons,
              preferredHeight: _lastKeyboardHeight,
            ),
          ),
        ),
        _ComposeImageUploadOptions(
          expanded: _uploadOptionsExpanded,
          source: _uploadSource,
          useOriginal: _useOriginalResolution,
          enabled: !_isSubmitting && !_isUploadingImage && !_preparingUpload,
          onExpandedChanged: (v) => setState(() => _uploadOptionsExpanded = v),
          onSourceChanged: (v) => setState(() => _uploadSource = v),
          onOriginalChanged: (v) => setState(() => _useOriginalResolution = v),
        ),
        _ComposeBottomBar(
          busy: busy,
          canSubmit: _canSubmit,
          canPreview: _canPreview,
          isSubmitting: _isSubmitting,
          isUploadingImage: _isUploadingImage || _preparingUpload,
          uploadProgressLabel: _preparingUpload
              ? '准备上传…'
              : (_isUploadingImage
                  ? (_uploadBatchTotal > 1
                      ? '上传中 ${_uploadBatchSuccess + 1}/$_uploadBatchTotal'
                      : '上传中')
                  : null),
          characterCount: composeMessageCharCount(
            _messageController.text,
            stripMediaPlaceholders: _editMediaDetached,
          ),
          emoticonPanelOpen: showPanel,
          onPickImage: _pickAndUploadImage,
          onToggleEmoticon: _toggleEmoticonPanel,
          onPreview: _showPreview,
          onSubmit: _submit,
          onBbcodeWrap: _applyBbcodeWrap,
          onInsertUrl: _insertUrlBbcode,
          onWrapColor: _applyBbcodeColor,
          onInsertCreditHide: _insertCreditHide,
          submitLabel:
              _isEditing ? (context.isExpandedOrAbove ? '保存编辑' : '保存') : '发送',
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (_canSubmit) _submit();
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (_canSubmit) _submit();
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          _applyBbcodeWrap('[b]', '[/b]');
        },
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          _applyBbcodeWrap('[b]', '[/b]');
        },
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          _applyBbcodeWrap('[i]', '[/i]');
        },
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
          _applyBbcodeWrap('[i]', '[/i]');
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _insertUrlBbcode();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _insertUrlBbcode();
        },
        const SingleActivator(LogicalKeyboardKey.escape):
            _dismissEmoticonPanelForShortcut,
      },
      child: PopScope(
        canPop: _allowPop || !_isDirty,
        onPopInvokedWithResult: _handlePop,
        child: Scaffold(
          backgroundColor: S1Surface.page(scheme),
          appBar: AppBar(
            elevation: 0,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_title, style: textTheme.titleLarge),
                if (forumName != null && forumName.isNotEmpty)
                  Text(
                    forumName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // 宽屏：写作区用 standard 限宽（840/1040）+ 一体 Card，避免「中间一条手机栏」。
          body: S1ContentWidth(
            mode: S1ContentWidthMode.standard,
            child: context.isExpandedOrAbove
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Card(
                      key: const ValueKey('compose_desktop_card'),
                      elevation: 0,
                      color: S1Surface.card(scheme),
                      clipBehavior: Clip.antiAlias,
                      margin: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius: S1Shape.large,
                        side: BorderSide.none,
                      ),
                      child: formColumn,
                    ),
                  )
                : formColumn,
          ),
        ),
      ),
    );
  }
}
