import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../models/quote_info.dart';
import '../models/new_thread_form_info.dart';
import '../models/edit_post_form_info.dart';
import '../models/edit_post_submit_result.dart';
import '../models/private_message_item.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/compose_provider.dart';
import '../providers/forum_name_provider.dart';
import '../providers/image_cache_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_list_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/compact_label.dart';
import '../utils/compose_img_tags.dart';
import '../utils/compose_message_draft.dart';
import '../utils/new_thread_draft.dart';
import '../utils/edit_post_draft.dart';
import '../utils/edit_post_message.dart';
import '../utils/platform_image_url.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/quote_builder.dart';
import '../utils/quote_snapshot_store.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/window_size.dart';
import '../widgets/bbcode_renderer.dart';
import '../widgets/compose_emoticon_panel.dart';
import '../widgets/quote_block.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_draft_leave_dialog.dart';
import '../widgets/s1_adaptive_sheet.dart';
import '../widgets/s1_content_width.dart';
import '../widgets/web_avatar.dart';

const _recentEmoticonsKey = 'compose_recent_emoticons';

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
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _redirectedToLogin = false;
  bool _allowPop = false;
  bool _showEmoticonPanel = false;
  QuoteSnapshot? _draft;
  bool _includeQuote = false;
  QuoteInfo? _quoteInfo;
  bool _quotePrefetching = false;
  String? _quotePrefetchError;
  final List<_ComposeUploadedImage> _uploadedImages = [];
  final Map<String, String> _imageLabelsByUrl = {};
  List<String> _recentEmoticons = [];
  Timer? _draftSaveTimer;
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

  /// 编辑页从服务器原文拆出的前置 `[quote]`（可移除，不进输入框）。
  String? _editLeadingQuote;

  /// 加载时拆出的正文基线（已去媒体标签；用于脏检查 / 草稿）。
  String _editLoadedBody = '';
  List<String> _editLoadedMediaTags = const [];
  bool _includeEditQuote = false;
  Map<String, String> _attachImageUrls = const {};
  ({Uint8List bytes, String filename})? _pendingUpload;

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
        _quotePrefetching ||
        _newThreadLoading ||
        _editLoading ||
        _editUncertain ||
        _editConflict;
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

  String get _draftEntryKey {
    final tid = widget.tid ?? '';
    return ComposeMessageDraft.entryKey(tid: tid, reppost: _quotePid);
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _subjectController.addListener(_onSubjectChanged);
    _messageFocusNode.addListener(_onMessageFocusChanged);
    if (widget.quoteSnapshotId != null) {
      _draft = QuoteSnapshotStore.peek(widget.quoteSnapshotId!);
    }
    final pid = _quotePid;
    _includeQuote = pid != null && pid.isNotEmpty;

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
    });
  }

  Future<void> _loadNewThreadForm() async {
    final fid = widget.fid;
    if (fid == null || fid.isEmpty) return;
    setState(() => _newThreadLoading = true);
    final form =
        await ref.read(composeControllerProvider).fetchNewThreadForm(fid: fid);
    if (!mounted) return;
    final saved = _readNewThreadDraft(fid);
    var restored = false;
    setState(() {
      _newThreadForm = form;
      _newThreadLoading = false;
      if (saved != null) {
        final subject = saved['subject'] as String? ?? '';
        final message = saved['message'] as String? ?? '';
        if (subject.trim().isNotEmpty || message.trim().isNotEmpty) {
          _suppressDraftSave = true;
          _subjectController.text = subject;
          _messageController.text = message;
          _selectedTypeId = saved['typeId'] as String?;
          _suppressDraftSave = false;
          restored = true;
        }
      }
    });
    if (restored && mounted) {
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
    final saved = _readEditDraft(pid);
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
      _selectedReadPerm = form.selectedReadPermission;
      _subjectController.text = form.subject;
      _editLeadingQuote = parts.leadingQuote;
      _editLoadedBody = mediaSplit.body;
      _editLoadedMediaTags = [for (final m in mediaSplit.media) m.tag];
      _includeEditQuote = parts.hasLeadingQuote;
      _messageController.text = mediaSplit.body;
      _applyEditMedia(mediaSplit.media);
    });
    _suppressMediaSync = false;
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
        final draftMsg = saved['message'] as String? ?? mediaSplit.body;
        final draftParts = EditPostMessageParts.split(draftMsg);
        // 草稿存的是可编辑正文（可含 ⟦图N⟧），不是整帖 raw。
        final draftBodyRaw = draftParts.hasLeadingQuote
            ? draftParts.body
            : (saved['message'] as String? ?? draftParts.body);
        final draftMedia = _mediaFromDraft(
          saved['mediaTags'],
          mediaSlots: saved['mediaSlots'],
          fallbackBody: draftBodyRaw,
        );
        _subjectController.text = saved['subject'] as String? ?? form.subject;
        _messageController.text = draftMedia.body;
        _selectedTypeId = saved['typeId'] as String? ?? form.selectedTypeId;
        _selectedReadPerm =
            saved['readPerm'] as String? ?? form.selectedReadPermission;
        final draftQuote = saved['leadingQuote'] as String?;
        setState(() {
          if (draftQuote != null && draftQuote.trim().isNotEmpty) {
            _editLeadingQuote = draftQuote;
          } else if (draftParts.hasLeadingQuote) {
            _editLeadingQuote = draftParts.leadingQuote;
          }
          _includeEditQuote = saved['includeQuote'] as bool? ??
              (_editLeadingQuote != null &&
                  _editLeadingQuote!.trim().isNotEmpty);
          _applyEditMedia(draftMedia.media, slots: draftMedia.effectiveSlots);
        });
        _suppressMediaSync = false;
        _suppressDraftSave = false;
      } else {
        _clearEditDraft(pid);
      }
    }
  }

  /// 草稿里的 `mediaTags` + 可选 `mediaSlots` + 正文（可含 `⟦图N⟧`）；旧草稿无占位时补上。
  ComposeMediaSplit _mediaFromDraft(
    Object? mediaTags, {
    Object? mediaSlots,
    required String fallbackBody,
  }) {
    if (mediaTags is! List) {
      return splitComposeMediaWithPlaceholders(
        fallbackBody,
        attachImageUrls: _attachImageUrls,
      );
    }
    final media = <ComposeMediaTag>[];
    for (final item in mediaTags) {
      final tag = item.toString().trim();
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

    final slots = <int>[];
    if (mediaSlots is List) {
      for (final raw in mediaSlots) {
        final slot = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
        slots.add(slot);
      }
    }
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

  Map<String, Object?>? _readEditDraft(String pid) {
    try {
      final store = ref.read(settingsStoreProvider);
      return EditPostDraftStore.read(
        EditPostDraftStore.parse(
          store.get<Object>(EditPostDraftStore.settingsKey),
        ),
        pid,
      );
    } on Object {
      return null;
    }
  }

  bool _editDraftDiffers(Map<String, Object?> draft, EditPostFormInfo form) {
    final parts = EditPostMessageParts.split(form.message);
    final serverMedia = splitComposeMediaWithPlaceholders(
      parts.body,
      attachImageUrls: {
        ...widget.editAttachImageUrls,
        ...form.attachImageUrls,
      },
    );
    final draftMsg = draft['message'] as String? ?? '';
    final draftParts = EditPostMessageParts.split(draftMsg);
    final draftMedia = _mediaFromDraft(
      draft['mediaTags'],
      mediaSlots: draft['mediaSlots'],
      fallbackBody: draftParts.body,
    );
    final draftInclude =
        draft['includeQuote'] as bool? ?? draftParts.hasLeadingQuote;
    final mediaChanged = draftMedia.media.length != serverMedia.media.length ||
        List.generate(
          draftMedia.media.length,
          (i) => draftMedia.media[i].tag != serverMedia.media[i].tag,
        ).any((changed) => changed);
    return draftMedia.body != serverMedia.body ||
        mediaChanged ||
        draftInclude != parts.hasLeadingQuote ||
        (draft['subject'] as String? ?? '') != form.subject ||
        (draft['typeId'] as String?) != form.selectedTypeId ||
        (draft['readPerm'] as String?) != form.selectedReadPermission;
  }

  void _persistEditDraft() {
    if (_suppressDraftSave) return;
    final pid = widget.editPid;
    final form = _editForm;
    if (!_isEditing || pid == null || form == null) return;
    final hadQuoteOnLoad =
        _editLeadingQuote != null && _editLeadingQuote!.trim().isNotEmpty;
    final unchanged = _messageController.text == _editLoadedBody &&
        _subjectController.text == form.subject &&
        _selectedTypeId == form.selectedTypeId &&
        _selectedReadPerm == form.selectedReadPermission &&
        _includeEditQuote == hadQuoteOnLoad &&
        !_editMediaChanged;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = EditPostDraftStore.parse(
        store.get<Object>(EditPostDraftStore.settingsKey),
      );
      if (unchanged) {
        store.put(
          EditPostDraftStore.settingsKey,
          EditPostDraftStore.toStoreValue(
            EditPostDraftStore.remove(drafts, pid),
          ),
        );
        return;
      }
      store.put(
        EditPostDraftStore.settingsKey,
        EditPostDraftStore.toStoreValue(
          EditPostDraftStore.upsert(
            drafts,
            pid,
            subject: _subjectController.text,
            message: _messageController.text,
            typeId: _selectedTypeId,
            readPerm: _selectedReadPerm,
            leadingQuote: _editLeadingQuote,
            includeQuote: _includeEditQuote,
            mediaTags: _currentMediaTags,
            mediaSlots: _currentMediaSlots,
          ),
        ),
      );
    } on Object {
      // 测试或无本地设置存储时跳过草稿持久化。
    }
  }

  void _clearEditDraft(String? pid) {
    if (pid == null || pid.isEmpty) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = EditPostDraftStore.parse(
        store.get<Object>(EditPostDraftStore.settingsKey),
      );
      store.put(
        EditPostDraftStore.settingsKey,
        EditPostDraftStore.toStoreValue(EditPostDraftStore.remove(drafts, pid)),
      );
    } on Object {
      // 无本地设置存储时跳过清理。
    }
  }

  Map<String, Object?>? _readNewThreadDraft(String fid) {
    try {
      final store = ref.read(settingsStoreProvider);
      return NewThreadDraftStore.read(
        NewThreadDraftStore.parse(
          store.get<Object>(NewThreadDraftStore.settingsKey),
        ),
        fid,
      );
    } on Object {
      return null;
    }
  }

  void _persistNewThreadDraft() {
    if (_suppressDraftSave) return;
    final fid = widget.fid;
    if (!_isNewThread || fid == null || fid.isEmpty) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = NewThreadDraftStore.parse(
        store.get<Object>(NewThreadDraftStore.settingsKey),
      );
      store.put(
        NewThreadDraftStore.settingsKey,
        NewThreadDraftStore.toStoreValue(
          NewThreadDraftStore.upsert(
            drafts,
            fid,
            subject: _subjectController.text,
            message: _messageController.text,
            typeId: _selectedTypeId,
          ),
        ),
      );
    } on Object {
      // 部分测试未注入 SettingsStore 时跳过草稿持久化。
    }
  }

  void _clearNewThreadDraft() {
    final fid = widget.fid;
    if (!_isNewThread || fid == null || fid.isEmpty) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = NewThreadDraftStore.parse(
        store.get<Object>(NewThreadDraftStore.settingsKey),
      );
      store.put(
        NewThreadDraftStore.settingsKey,
        NewThreadDraftStore.toStoreValue(
          NewThreadDraftStore.remove(drafts, fid),
        ),
      );
    } on Object {
      // 部分测试未注入 SettingsStore 时跳过清理。
    }
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
    if (_isEditing || _isNewThread) return;
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

  void _scheduleReplyDraftSave() {
    if (_suppressDraftSave || _isEditing || _isNewThread) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(ComposeMessageDraft.debounce, _persistReplyDraft);
  }

  void _persistReplyDraft() {
    if (_isEditing || _isNewThread) return;
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

  void _clearReplyDraft() {
    if (_isEditing || _isNewThread) return;
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

  void _flushDraftForMode() {
    if (_isEditing) {
      _persistEditDraft();
    } else if (_isNewThread) {
      _persistNewThreadDraft();
    } else {
      _persistReplyDraft();
    }
  }

  void _clearDraftForMode() {
    if (_isEditing) {
      _clearEditDraft(widget.editPid);
    } else if (_isNewThread) {
      _clearNewThreadDraft();
    } else {
      _clearReplyDraft();
    }
  }

  void _onMessageChanged() {
    if (!mounted) return;
    if (!_suppressMediaSync && !_editMediaDetached) {
      final urls = extractImgUrls(_messageController.text);
      final next = <_ComposeUploadedImage>[
        for (final url in urls)
          _ComposeUploadedImage(
            tag: '[img]$url[/img]',
            label: _imageLabelsByUrl[url] ?? filenameFromUrl(url),
            previewUrl: url,
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
    if (_isEditing) {
      _persistEditDraft();
    } else if (_isNewThread) {
      _persistNewThreadDraft();
    } else {
      _scheduleReplyDraftSave();
    }
  }

  void _onSubjectChanged() {
    if (_isNewThread) {
      _persistNewThreadDraft();
    } else if (_isEditing) {
      _persistEditDraft();
    }
    if (mounted) setState(() {});
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
      quoteInfo = _quoting ? _quoteInfo : null;
      previewBbcode =
          await ref.read(composeControllerProvider).applySignature(message);
    }
    if (!mounted) return;

    final previewSubject = _isNewThread
        ? _subjectController.text.trim()
        : (_subjectLabel?.trim() ?? '');
    final auth = ref.read(authStateProvider);
    final authorName = auth.user?.username ?? auth.username ?? '我';
    final authorAvatar = User.resolveAvatarUrl(
          auth.user?.avatar,
          size: 'middle',
        ) ??
        PrivateMessageItem.avatarUrlForUid(auth.user?.uid ?? '');

    await showS1AdaptiveSheet<void>(
      context: context,
      isScrollControlled: true,
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
      ),
    );
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    // 仅回复模式 flush compose_message_drafts；编辑/新主题禁止写入该键。
    if (!_allowPop &&
        !_isEditing &&
        !_isNewThread &&
        _messageController.text.trim().isNotEmpty) {
      _persistReplyDraft();
    }
    _messageController.removeListener(_onMessageChanged);
    _subjectController.removeListener(_onSubjectChanged);
    _messageFocusNode.removeListener(_onMessageFocusChanged);
    _messageController.dispose();
    _subjectController.dispose();
    _messageFocusNode.dispose();
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
      _persistEditDraft();
      return;
    }
    final url = image.previewUrl;
    if (url == null || url.isEmpty) return;
    final next = removeImgTag(_messageController.text, url);
    _imageLabelsByUrl.remove(url);
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
      final label = pending.filename.trim().isEmpty ? '图片' : pending.filename;
      _imageLabelsByUrl[url] = label;
      if (_editMediaDetached) {
        final slot = _nextEditMediaSlot();
        final selection = _messageController.selection;
        final start = selection.isValid
            ? selection.start
            : _messageController.text.length;
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
        setState(() {
          _uploadedImages.add(
            _ComposeUploadedImage(
              tag: '[img]$url[/img]',
              label: label,
              previewUrl: url,
              slot: slot,
            ),
          );
          _pendingUpload = null;
        });
        _suppressMediaSync = false;
        _persistEditDraft();
        S1SnackBar.show(context, message: '图片已添加', bottomClearance: 72);
      } else {
        final selection = _messageController.selection;
        final start = selection.isValid
            ? selection.start
            : _messageController.text.length;
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
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(
          context,
          message: e.toString(),
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
        return;
      }
      final confirmed = await showS1ConfirmDialog(
        context,
        title: '确认发布主题？',
        content: '版块 ID：${widget.fid}\n标题：$subject\n发布后将对其他用户可见。',
        confirmLabel: '发布',
      );
      if (!mounted || !confirmed) return;
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
          _clearNewThreadDraft();
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
      if (stripComposeMediaPlaceholders(userText).trim().isEmpty &&
          _uploadedImages.isEmpty) {
        S1SnackBar.show(context, message: '请输入正文', bottomClearance: 72);
        return;
      }
      final confirmed = await showS1ConfirmDialog(
        context,
        title: '确认覆盖帖子内容？',
        content: widget.editIsFirst
            ? '标题：${_subjectController.text.trim()}\n提交后将覆盖服务器上的主题内容。'
            : '提交后将覆盖服务器上的回复内容。',
        confirmLabel: '确认编辑',
      );
      if (!mounted || !confirmed) return;
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
          _clearEditDraft(pid);
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
          _clearReplyDraft();
          S1SnackBar.show(context, message: '回复成功', bottomClearance: 16);
          _allowPopAndExit(result);
        } else {
          S1SnackBar.error(
            context,
            message: result.error ?? '回复失败',
            bottomClearance: 72,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.error(context, message: '$e', bottomClearance: 72);
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
    _persistEditDraft();
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
      _clearEditDraft(widget.editPid);
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
        _flushDraftForMode();
        break;
      case S1DraftLeaveChoice.discardAndLeave:
        _clearDraftForMode();
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
        _quotePrefetching ||
        _newThreadLoading ||
        _editLoading ||
        _editUncertain ||
        _editConflict;
    // 回复编辑与回复页一致展示主题；一楼编辑已有可改标题控件，不再叠一行。
    final subject = (_isEditing && widget.editIsFirst) ? null : _subjectLabel;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
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
            onTypeChanged: (value) {
              setState(() {
                _selectedTypeId = value;
                _persistNewThreadDraft();
              });
            },
          ),
        if (_isEditing)
          _EditPostHeader(
            form: _editForm,
            controller: _subjectController,
            selectedTypeId: _selectedTypeId,
            selectedReadPerm: _selectedReadPerm,
            onTypeChanged: (value) {
              setState(() {
                _selectedTypeId = value;
                _persistEditDraft();
              });
            },
            onReadPermChanged: (value) {
              setState(() {
                _selectedReadPerm = value;
                _persistEditDraft();
              });
            },
          ),
        if (_isEditing && (_editUncertain || _editConflict))
          _EditPostStatus(
            message:
                _editUncertain ? '编辑结果不确定，请先核对服务器内容。' : '服务器内容已变化，请重新载入后再编辑。',
            actionLabel: '核对服务器',
            onPressed: _recheckEditState,
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
          submitLabel: _isEditing ? '保存编辑' : '发送',
        ),
      ],
    );

    return PopScope(
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
    );
  }
}

/// 发帖 / 回复预览：Dialog 画布 + 一帖 Card（对齐读帖 surface 层级）。
/// 主题在卡上方；卡内只预览楼层正文。
class _ComposePreviewSheet extends StatelessWidget {
  const _ComposePreviewSheet({
    required this.subject,
    required this.isNewThread,
    required this.isEditing,
    required this.quoteInfo,
    required this.previewBbcode,
    required this.tid,
    required this.authorName,
    this.authorAvatar,
    this.attachPreviewLimited = false,
  });

  final String? subject;
  final bool isNewThread;
  final bool isEditing;
  final QuoteInfo? quoteInfo;
  final String previewBbcode;
  final String? tid;
  final String authorName;
  final String? authorAvatar;

  /// 仍有未解析的 `[attachimg]`，预览里可能显示附件码。
  final bool attachPreviewLimited;

  String get _floorLabel {
    if (isEditing) return '编辑';
    if (isNewThread) return '#1';
    return '回复';
  }

  /// 回复已有「即将回复」副文案，不再叠一颗「回复」Chip；新主题 / 编辑保留楼层标记。
  bool get _showFloorMark => isNewThread || isEditing;

  String get _metaLabel {
    if (isEditing) return '编辑后效果';
    if (isNewThread) return '即将发布';
    return '即将回复';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final desktop = context.isExpandedOrAbove;
    final maxHeight =
        MediaQuery.sizeOf(context).height * (desktop ? 0.78 : 0.72);
    final imageIndexCounter = PostImageIndexCounter();
    final letter = authorName.isNotEmpty ? authorName[0] : '?';
    // 主题始终在卡上方作上下文；卡内只预览楼层正文（含签名）。
    final showSubjectAbove = subject != null;

    final postCard = Card(
      elevation: 0,
      color: S1Surface.card(scheme),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                WebAvatar(
                  url: authorAvatar,
                  radius: 20,
                  fallbackLetter: letter,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _metaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showFloorMark)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: S1Shape.extraSmall,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: CompactLabel.text(
                        _floorLabel,
                        style: CompactLabel.style(
                          context,
                          base: textTheme.labelSmall,
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Divider(height: 16, color: scheme.outlineVariant),
            if (quoteInfo != null)
              QuoteBlock(
                content: EditPostMessageParts(
                      leadingQuote: quoteInfo!.noticeTrimStr,
                      body: '',
                    ).quoteInner ??
                    quoteInfo!.noticeTrimStr,
                imageIndexCounter: imageIndexCounter,
                currentTid: tid,
              ),
            BbcodeRenderer(
              bbcode: previewBbcode.isEmpty ? '（无内容）' : previewBbcode,
              imageIndexCounter: imageIndexCounter,
              // Dialog 打开动画首帧 SelectionArea 会 assert !debugNeedsLayout。
              selectable: false,
            ),
          ],
        ),
      ),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '预览',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            // PC Dialog：TextButton「关闭」属 M3 actions 语义；不放顶栏 X
            //（AGENTS：adaptive sheet 不放关闭 chrome，桌面靠 scrim / Escape）。
            if (desktop)
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('关闭'),
              ),
          ],
        ),
        if (showSubjectAbove) ...[
          const SizedBox(height: 8),
          Text(
            isNewThread ? subject! : '主题 · $subject',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (isNewThread ? textTheme.titleMedium : textTheme.labelLarge)
                ?.copyWith(
              color: isNewThread ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: isNewThread ? FontWeight.w600 : null,
            ),
          ),
        ],
        if (attachPreviewLimited) ...[
          const SizedBox(height: 8),
          Text(
            '部分论坛附件图暂无地址，预览可能显示附件码；保存后仍会按原附件提交。',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return SafeArea(
      child: desktop
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: postCard,
                    ),
                  ],
                ),
              ),
            )
          : SizedBox(
              height: maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: header,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: postCard,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 发帖元信息（标题 / 分类 / 权限）共用：filled 色阶，无硬描边。
InputDecorationTheme _composeMetaInputTheme(ColorScheme scheme) {
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surfaceContainerHigh,
    border: const OutlineInputBorder(
      borderRadius: S1Shape.small,
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: S1Shape.small,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: S1Shape.small,
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

InputDecoration _composeMetaDecoration(
  BuildContext context, {
  required String labelText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final theme = _composeMetaInputTheme(scheme);
  return InputDecoration(
    labelText: labelText,
    filled: theme.filled,
    fillColor: theme.fillColor,
    border: theme.border,
    enabledBorder: theme.enabledBorder,
    focusedBorder: theme.focusedBorder,
    contentPadding: theme.contentPadding,
  );
}

/// M3 [DropdownMenu]：浮层菜单（圆角 + 低 elevation），替代割裂的 [DropdownButtonFormField]。
class _ComposeDropdownMenu extends StatelessWidget {
  const _ComposeDropdownMenu({
    required this.label,
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<({String value, String label})> entries;
  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _noneValue = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String effective;
    if (selected != null && entries.any((e) => e.value == selected)) {
      effective = selected!;
    } else if (entries.any((e) => e.value == _noneValue)) {
      effective = _noneValue;
    } else if (entries.isNotEmpty) {
      effective = entries.first.value;
    } else {
      effective = _noneValue;
    }

    return DropdownMenu<String>(
      key: ValueKey('$label-$effective'),
      initialSelection: effective,
      label: Text(label),
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: _composeMetaInputTheme(scheme),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(scheme.shadow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: S1Shape.small),
        ),
        maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 320)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      dropdownMenuEntries: [
        for (final entry in entries)
          DropdownMenuEntry<String>(
            value: entry.value,
            label: entry.label,
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.bodyLarge,
              ),
              maximumSize: const WidgetStatePropertyAll(
                Size(double.infinity, double.infinity),
              ),
            ),
          ),
      ],
      onSelected: (value) {
        if (value == null || value == _noneValue) {
          onSelected(null);
        } else {
          onSelected(value);
        }
      },
    );
  }
}

/// 正文 filled 输入：空态用 Highest 凹槽；有内容 / 聚焦时降到 Low，区分「内容态」。
class _NewThreadHeader extends StatelessWidget {
  const _NewThreadHeader({
    required this.form,
    required this.controller,
    required this.selectedTypeId,
    required this.onTypeChanged,
  });

  final NewThreadFormInfo? form;
  final TextEditingController controller;
  final String? selectedTypeId;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (form == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (form?.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          form!.error!,
          style: textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    final types = form?.threadTypes ?? const <String, String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                textInputAction: TextInputAction.next,
                style: textTheme.titleMedium,
                decoration: _composeMetaDecoration(context, labelText: '主题标题'),
              ),
              if (types.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ComposeDropdownMenu(
                  label: '主题分类',
                  selected: selectedTypeId,
                  onSelected: onTypeChanged,
                  entries: [
                    if (!(form?.typeRequired ?? false))
                      (value: '', label: '不分类'),
                    for (final entry in types.entries)
                      (value: entry.key, label: entry.value),
                  ],
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
        ),
      ],
    );
  }
}

class _EditPostHeader extends StatelessWidget {
  const _EditPostHeader({
    required this.form,
    required this.controller,
    required this.selectedTypeId,
    required this.selectedReadPerm,
    required this.onTypeChanged,
    required this.onReadPermChanged,
  });

  final EditPostFormInfo? form;
  final TextEditingController controller;
  final String? selectedTypeId;
  final String? selectedReadPerm;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onReadPermChanged;

  @override
  Widget build(BuildContext context) {
    final form = this.form;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (form?.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          form!.error!,
          style: textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    if (form == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (form.isFirst)
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.next,
                  style: textTheme.titleMedium,
                  decoration:
                      _composeMetaDecoration(context, labelText: '主题标题'),
                ),
              if (form.threadTypes.isNotEmpty) ...[
                if (form.isFirst) const SizedBox(height: 12),
                _ComposeDropdownMenu(
                  label: '主题分类',
                  selected: form.threadTypes.containsKey(selectedTypeId)
                      ? selectedTypeId
                      : null,
                  onSelected: onTypeChanged,
                  entries: [
                    (value: '', label: '不分类'),
                    for (final entry in form.threadTypes.entries)
                      (value: entry.key, label: entry.value),
                  ],
                ),
              ],
              if (form.readPermissions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ComposeDropdownMenu(
                  label: '阅读权限',
                  selected: form.readPermissions.contains(selectedReadPerm)
                      ? selectedReadPerm
                      : null,
                  onSelected: onReadPermChanged,
                  entries: [
                    for (final permission in form.readPermissions)
                      (
                        value: permission,
                        label: permission == '0' ? '不限' : permission,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
        ),
      ],
    );
  }
}

class _EditPostStatus extends StatelessWidget {
  const _EditPostStatus({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onPressed,
              child: Text(
                actionLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeMessageField extends StatelessWidget {
  const _ComposeMessageField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasContent = controller.text.trim().isNotEmpty;
    final focused = focusNode.hasFocus;
    final active = hasContent || focused;
    final desktop = context.isExpandedOrAbove;
    // 桌面 Card 内透明贴合奶油表面；手机保持 Highest 凹槽 / Low 内容态。
    final fillColor = desktop
        ? Colors.transparent
        : (active
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHighest);

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
          hintText: hintText,
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          // expands 输入框底边 underline 会横在工具栏上方，看起来像粗分隔线。
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
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
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color:
                        _expanded ? scheme.onSurface : scheme.onSurfaceVariant,
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
    this.title,
    this.preview,
    required this.onRemove,
    this.loading = false,
    this.error,
  });

  final Post? post;
  final int displayFloor;

  /// 编辑页等：直接给标题/摘要（优先于 [post]）。
  final String? title;
  final String? preview;
  final VoidCallback onRemove;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final post = this.post;
    final resolvedPreview =
        preview ?? (post == null ? '' : QuoteBuilder.previewText(post.message));
    final resolvedTitle = title ??
        (post == null
            ? '引用楼层'
            : displayFloor > 0
                ? '引用 #$displayFloor 楼 · ${post.author}'
                : '引用 ${post.author}');

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
                          resolvedTitle,
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
                        if (resolvedPreview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            resolvedPreview,
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

class _ComposeMediaPreviewHint extends StatelessWidget {
  const _ComposeMediaPreviewHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Text(
          '正文中的 ⟦图N⟧ 可挪动以调整排版；无缩略图的论坛附件仍会保存。',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
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
                avatar: _ComposeImageChipAvatar(image: image),
                label: SizedBox(
                  width: maxLabelWidth,
                  child: Text(
                    displayLabelForIndex(
                      (image.slot != null && image.slot! > 0)
                          ? image.slot! - 1
                          : index,
                    ),
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

/// Chip 头像：有 URL 显示缩略图，否则按附件类型给图标。
class _ComposeImageChipAvatar extends StatelessWidget {
  const _ComposeImageChipAvatar({required this.image});

  final _ComposeUploadedImage image;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.onSecondaryContainer;
    if (!image.hasThumb) {
      return Icon(
        image.isForumAttach
            ? Icons.attach_file
            : (image.isAttachimg
                ? Icons.image_not_supported_outlined
                : Icons.image_outlined),
        size: 18,
        color: iconColor,
      );
    }

    final url = platformImageUrl(image.previewUrl!.trim(), isWeb: kIsWeb);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: s1ImageCacheManager,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => Icon(
          Icons.image_outlined,
          size: 18,
          color: iconColor,
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: iconColor,
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
    this.submitLabel = '发送',
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
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final desktop = context.isExpandedOrAbove;

    return Material(
      color: desktop ? Colors.transparent : S1BottomBarStyle.background(scheme),
      elevation: 0,
      child: AnimatedPadding(
        duration: S1Motion.rapid,
        curve: S1Motion.standard,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
              ),
              Padding(
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
                      style: FilledButton.styleFrom(
                        disabledForegroundColor: scheme.onSurface
                            .withValues(alpha: S1Alpha.disabledIcon),
                        disabledBackgroundColor:
                            scheme.onSurface.withValues(alpha: S1Alpha.subtle),
                      ),
                      child: isSubmitting
                          ? Text(
                              '发送中…',
                              style: textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimary,
                              ),
                            )
                          : Text(submitLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
