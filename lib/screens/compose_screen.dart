import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
import '../providers/settings_provider.dart';
import '../providers/thread_list_provider.dart';
import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import '../utils/compose_draft_store.dart';
import '../utils/compose_img_tags.dart';
import '../utils/compose_message_draft.dart';
import '../utils/new_thread_draft.dart';
import '../utils/edit_post_draft.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/quote_builder.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/window_size.dart';
import '../widgets/bbcode_renderer.dart';
import '../widgets/compose_emoticon_panel.dart';
import '../widgets/quote_block.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_adaptive_sheet.dart';
import '../widgets/s1_content_width.dart';
import '../widgets/web_avatar.dart';

const _recentEmoticonsKey = 'compose_recent_emoticons';

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({
    super.key,
    this.tid,
    this.fid,
    this.draftId,
    this.reppost,
    this.subject,
    this.newThread = false,
    this.editPid,
    this.editPage,
    this.editIsFirst = false,
  });

  final String? tid;
  final String? fid;
  final String? draftId;
  final String? reppost;
  final String? subject;
  final bool newThread;
  final String? editPid;
  final int? editPage;
  final bool editIsFirst;

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
  final _subjectController = TextEditingController();
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
  NewThreadFormInfo? _newThreadForm;
  bool _newThreadLoading = false;
  String? _selectedTypeId;
  String? _selectedReadPerm;
  EditPostFormInfo? _editForm;
  bool _editLoading = false;
  bool _editUncertain = false;
  bool _editConflict = false;
  ({Uint8List bytes, String filename})? _pendingUpload;

  bool get _hasValidTid => widget.tid != null && widget.tid!.isNotEmpty;
  bool get _isNewThread => widget.newThread;
  bool get _isEditing => widget.editPid != null && widget.editPid!.isNotEmpty;

  String? get _quotePid => widget.reppost ?? _draft?.post.pid;

  String? get _subjectLabel {
    final subject = widget.subject?.trim();
    if (subject == null || subject.isEmpty) return null;
    return subject;
  }

  bool get _quoting => _includeQuote && _quoteInfo != null;

  bool get _isDirty {
    if (_isEditing && _editForm != null) {
      return _messageController.text != _editForm!.message ||
          _subjectController.text != _editForm!.subject ||
          _selectedTypeId != _editForm!.selectedTypeId ||
          _selectedReadPerm != _editForm!.selectedReadPermission ||
          _uploadedImages.isNotEmpty;
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
    if (_isNewThread) {
      return _subjectController.text.trim().isNotEmpty && hasText;
    }
    if (_isEditing) {
      return _editForm != null && hasText;
    }
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
    _subjectController.addListener(_onSubjectChanged);
    _messageFocusNode.addListener(_onMessageFocusChanged);
    if (widget.draftId != null) {
      _draft = ComposeDraftStore.peek(widget.draftId!);
    }
    final pid = _quotePid;
    _includeQuote = pid != null && pid.isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRecentEmoticons();
      if (!_isEditing) _restoreMessageDraft();
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
    setState(() {
      _newThreadForm = form;
      _newThreadLoading = false;
      if (saved != null) {
        _subjectController.text = saved['subject'] as String? ?? '';
        _messageController.text = saved['message'] as String? ?? '';
        _selectedTypeId = saved['typeId'] as String?;
      }
    });
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
    setState(() {
      _editForm = form;
      _editLoading = false;
      _selectedTypeId = form.selectedTypeId;
      _selectedReadPerm = form.selectedReadPermission;
      _subjectController.text = form.subject;
      _messageController.text = form.message;
    });
    if (saved != null && _editDraftDiffers(saved, form)) {
      final restore = await showS1ConfirmDialog(
        context,
        title: '恢复编辑草稿？',
        content: '服务器内容可能已有变化，恢复草稿后仍会再次检查冲突。\n'
            '点击“确定”恢复草稿，点击“取消”使用服务器内容。',
        confirmLabel: '恢复草稿',
      );
      if (!mounted) return;
      if (restore) {
        _suppressDraftSave = true;
        _subjectController.text = saved['subject'] as String? ?? form.subject;
        _messageController.text = saved['message'] as String? ?? form.message;
        _selectedTypeId = saved['typeId'] as String? ?? form.selectedTypeId;
        _selectedReadPerm =
            saved['readPerm'] as String? ?? form.selectedReadPermission;
        _suppressDraftSave = false;
      } else {
        _clearEditDraft(pid);
      }
    }
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
    return (draft['message'] as String? ?? '') != form.message ||
        (draft['subject'] as String? ?? '') != form.subject ||
        (draft['typeId'] as String?) != form.selectedTypeId ||
        (draft['readPerm'] as String?) != form.selectedReadPermission;
  }

  void _persistEditDraft() {
    final pid = widget.editPid;
    final form = _editForm;
    if (!_isEditing || pid == null || form == null) return;
    final unchanged = _messageController.text == form.message &&
        _subjectController.text == form.subject &&
        _selectedTypeId == form.selectedTypeId &&
        _selectedReadPerm == form.selectedReadPermission;
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
            sourceSubject: form.subject,
            sourceMessage: form.message,
            sourceTypeId: form.selectedTypeId,
            sourceReadPerm: form.selectedReadPermission,
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
    if (_isNewThread) _persistNewThreadDraft();
    if (_isEditing) _persistEditDraft();
  }

  void _onSubjectChanged() {
    if (_isNewThread) _persistNewThreadDraft();
    if (_isEditing) _persistEditDraft();
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
    final quoteInfo = _quoting ? _quoteInfo : null;
    final tid = widget.tid;
    final previewBbcode = _isEditing
        ? message
        : await ref.read(composeControllerProvider).applySignature(message);
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
      ),
    );
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    if (!_allowPop && _messageController.text.trim().isNotEmpty) {
      _persistDraft();
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
      final label = pending.filename.trim().isEmpty ? '图片' : pending.filename;
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
          setState(() => _allowPop = true);
          context.pop(result);
        } else {
          S1SnackBar.show(
            context,
            message: result.error ?? '发帖失败',
            bottomClearance: 72,
          );
        }
      } catch (e) {
        if (mounted) {
          S1SnackBar.show(context, message: '$e', bottomClearance: 72);
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
      if (userText.isEmpty) {
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
      setState(() => _isSubmitting = true);
      try {
        final result = await ref.read(composeControllerProvider).submitEditPost(
              fid: widget.fid!,
              tid: widget.tid!,
              pid: pid,
              isFirst: widget.editIsFirst,
              subject: _subjectController.text,
              message: userText,
              typeId: _selectedTypeId,
              readPerm: _selectedReadPerm,
              baseline: form,
            );
        if (!mounted) return;
        if (result.isSuccess) {
          _clearEditDraft(pid);
          setState(() => _allowPop = true);
          context.pop(result);
        } else if (result.isConflict) {
          setState(() => _editConflict = true);
          S1SnackBar.show(
            context,
            message: result.message ?? '服务器内容已变化，请重新载入',
            bottomClearance: 72,
          );
        } else if (result.isUncertain) {
          setState(() => _editUncertain = true);
          S1SnackBar.show(
            context,
            message: result.message ?? '编辑状态不确定，请先核对服务器内容',
            bottomClearance: 72,
          );
        } else {
          S1SnackBar.show(
            context,
            message: result.message ?? '编辑失败',
            bottomClearance: 72,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _editUncertain = true);
          S1SnackBar.show(context, message: '$e', bottomClearance: 72);
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
          final draftId = widget.draftId;
          if (draftId != null) ComposeDraftStore.remove(draftId);
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
    final matchesDesired =
        latest.message.trim() == _messageController.text.trim() &&
            (!widget.editIsFirst ||
                latest.subject.trim() == _subjectController.text.trim());
    if (matchesDesired) {
      _clearEditDraft(widget.editPid);
      setState(() {
        _editLoading = false;
        _allowPop = true;
      });
      context.pop(const EditPostSubmitResult.success(message: '编辑成功'));
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

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _allowPop) return;
    if (!_isDirty) return;

    final discard = await showS1ConfirmDialog(
      context,
      title: _isNewThread ? '放弃新主题？' : (_isEditing ? '放弃编辑？' : '放弃回复？'),
      content: _isNewThread
          ? '放弃后将清除本地新主题草稿。'
          : (_isEditing ? '编辑草稿将被保留，下次可继续恢复。' : '本回复草稿将被放弃。'),
      confirmLabel: '放弃',
      destructive: true,
    );
    if (!mounted || !discard) return;
    if (_isEditing) {
      _persistEditDraft();
    } else {
      _clearMessageDraft();
    }
    setState(() => _allowPop = true);
    context.pop();
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
    final subject = _isEditing ? null : _subjectLabel;
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
        if (_includeQuote && !_isNewThread)
          _ComposeQuoteBanner(
            post: _draft?.post,
            displayFloor: _draft?.displayFloor ?? 0,
            onRemove: _removeQuote,
            loading: _quotePrefetching,
            error: _quotePrefetchError,
          ),
        if (subject != null && !_isNewThread)
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
  });

  final String? subject;
  final bool isNewThread;
  final bool isEditing;
  final QuoteInfo? quoteInfo;
  final String previewBbcode;
  final String? tid;
  final String authorName;
  final String? authorAvatar;

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
                content: quoteInfo!.noticeTrimStr,
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
    final preview = post == null ? '' : QuoteBuilder.previewText(post.message);
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
