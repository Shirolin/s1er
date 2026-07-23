import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../models/compose_image_upload_result.dart';
import '../models/forum_attachment_upload_info.dart';
import '../models/post.dart';
import '../models/quote_info.dart';
import '../models/reply_submit_result.dart';
import '../models/new_thread_form_info.dart';
import '../models/new_thread_submit_result.dart';
import '../models/edit_post_form_info.dart';
import '../models/edit_post_submit_result.dart';
import '../services/device_model_label.dart';
import '../services/external_image_upload_service.dart';
import '../services/forum_attachment_upload_service.dart';
import '../utils/compose_image_compress.dart';
import '../utils/post_signature.dart';
import '../utils/quote_builder.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart';
import 'device_model_label_provider.dart';
import 'settings_provider.dart';
import '../services/http_client.dart';

/// 插图上传来源。
enum ComposeImageUploadSource {
  /// Discuz 论坛附件（默认）。
  forum,

  /// p.sda1.dev 外链图床。
  external,
}

/// 回复编排：预取官方引用字段 + 提交 `module=sendreply`。
class ComposeController {
  ComposeController(this._ref);

  final Ref _ref;

  ForumAttachmentUploadInfo? _cachedUploadInfo;
  String? _cachedUploadInfoKey;

  Future<QuoteInfo?> prefetchQuote({
    required String tid,
    required String pid,
  }) {
    return _ref.read(apiServiceProvider).fetchQuoteInfo(tid: tid, pid: pid);
  }

  /// 后台预取论坛附件上传凭据；失败不抛，选图时再试。
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    ForumAttachmentUploadInfo? seed,
  }) async {
    if (seed != null && seed.isValid) {
      _cacheUploadInfo(fid: fid, tid: tid, editPid: editPid, info: seed);
      return seed;
    }
    final cached = _cachedFor(fid: fid, tid: tid, editPid: editPid);
    if (cached != null) return cached;
    final info = await _ref
        .read(apiServiceProvider)
        .fetchForumAttachmentUploadInfo(
          fid: fid,
          tid: tid,
          editPid: editPid,
        );
    if (info != null && info.isValid) {
      _cacheUploadInfo(fid: fid, tid: tid, editPid: editPid, info: info);
    }
    return info;
  }

  /// [message] 只含用户正文（可含 `[img]` / `[attachimg]`），不含客户端拼的 `[quote]`。
  Future<ReplySubmitResult> submitReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    Post? quotedPost,
  }) async {
    final effectiveQuote = quoteInfoForSubmit(
      quoteInfo: quoteInfo,
      quotedPost: quotedPost,
      tid: tid,
    );
    final signed = await _messageWithSignature(message);
    return _ref.read(apiServiceProvider).sendReply(
          tid: tid,
          fid: fid,
          message: signed,
          quoteInfo: effectiveQuote,
          noticeAuthorMsg: message,
        );
  }

  /// 可见以便单测：官方 noticeauthor + 可持久化 findpost 的 trim。
  static QuoteInfo? quoteInfoForSubmit({
    required QuoteInfo? quoteInfo,
    Post? quotedPost,
    required String tid,
  }) {
    if (quoteInfo == null) return null;
    if (quotedPost == null || tid.isEmpty) return quoteInfo;
    return QuoteInfo(
      noticeAuthor: quoteInfo.noticeAuthor,
      noticeTrimStr: QuoteBuilder.buildQuoteBbcode(
        post: quotedPost,
        tid: tid,
      ),
    );
  }

  Future<NewThreadFormInfo> fetchNewThreadForm({required String fid}) {
    return _ref.read(apiServiceProvider).fetchNewThreadForm(fid: fid);
  }

  Future<NewThreadSubmitResult> submitNewThread({
    required String fid,
    required String subject,
    required String message,
    String? typeId,
  }) async {
    final signed = await _messageWithSignature(message);
    return _ref.read(apiServiceProvider).submitNewThread(
          fid: fid,
          subject: subject,
          message: signed,
          typeId: typeId,
        );
  }

  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) {
    return _ref.read(apiServiceProvider).fetchEditPostForm(
          fid: fid,
          tid: tid,
          pid: pid,
          isFirst: isFirst,
        );
  }

  Future<EditPostSubmitResult> submitEditPost({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
    required String subject,
    required String message,
    String? typeId,
    String? readPerm,
    required EditPostFormInfo baseline,
  }) async {
    final signed = await _messageWithSignature(message);
    return _ref.read(apiServiceProvider).submitEditPost(
          fid: fid,
          tid: tid,
          pid: pid,
          isFirst: isFirst,
          subject: subject,
          message: signed,
          typeId: typeId,
          readPerm: readPerm,
          baseline: baseline,
        );
  }

  /// 按来源上传：默认论坛附件；外链走 p.sda1.dev。
  Future<ComposeImageUploadResult> uploadImage({
    required List<int> bytes,
    required String filename,
    required String fid,
    String? tid,
    String? editPid,
    ComposeImageUploadSource source = ComposeImageUploadSource.forum,
    bool useOriginalResolution = false,
    ForumAttachmentUploadInfo? seedUploadInfo,
  }) async {
    final compressed = await ComposeImageCompress.maybeCompress(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      useOriginal: useOriginalResolution,
    );

    if (source == ComposeImageUploadSource.external) {
      final url = await _ref.read(externalImageUploadServiceProvider).upload(
            bytes: compressed.bytes,
            filename: compressed.filename,
          );
      return ComposeImageUploadResult(
        insertTag: '[img]$url[/img]',
        label: compressed.filename,
        previewUrl: url,
      );
    }

    final info = await prefetchAttachmentUploadInfo(
      fid: fid,
      tid: tid,
      editPid: editPid,
      seed: seedUploadInfo,
    );
    if (info == null || !info.isValid) {
      throw const ForumAttachmentUploadException(
        '无法获取论坛上传参数，请稍后重试',
      );
    }

    final uid = info.uid?.trim().isNotEmpty == true
        ? info.uid!.trim()
        : (_ref.read(authStateProvider).user?.uid.trim() ?? '');
    final referer = ApiConfig.forumAttachmentReferer(
      fid: fid,
      tid: tid,
      editPid: editPid,
    );

    return _ref.read(forumAttachmentUploadServiceProvider).upload(
          bytes: compressed.bytes,
          filename: compressed.filename,
          info: info,
          uid: uid,
          referer: referer,
        );
  }

  ForumAttachmentUploadInfo? _cachedFor({
    required String fid,
    String? tid,
    String? editPid,
  }) {
    final key = _cacheKey(fid: fid, tid: tid, editPid: editPid);
    if (_cachedUploadInfoKey == key) return _cachedUploadInfo;
    return null;
  }

  void _cacheUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    required ForumAttachmentUploadInfo info,
  }) {
    _cachedUploadInfoKey = _cacheKey(fid: fid, tid: tid, editPid: editPid);
    _cachedUploadInfo = info;
  }

  static String _cacheKey({
    required String fid,
    String? tid,
    String? editPid,
  }) =>
      '${fid}_${tid ?? ''}_${editPid ?? ''}';

  /// 按当前设置追加小尾巴（预览与发帖/回复提交共用）。
  Future<String> applySignature(String message) =>
      _messageWithSignature(message);

  Future<String> _messageWithSignature(String message) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.postSignatureEnabled) {
      return PostSignature.appendIfEnabled(
        message,
        enabled: false,
        showDevice: false,
        custom: '',
      );
    }

    String? deviceLabel;
    if (settings.postSignatureShowDevice) {
      try {
        deviceLabel = await _ref.read(deviceModelLabelProvider.future);
      } catch (_) {
        deviceLabel = DeviceModelLabel.coarseFallback();
      }
    }

    return PostSignature.appendIfEnabled(
      message,
      enabled: true,
      showDevice: settings.postSignatureShowDevice,
      custom: settings.postSignatureCustom,
      deviceLabel: deviceLabel,
    );
  }
}

final composeControllerProvider = Provider<ComposeController>((ref) {
  return ComposeController(ref);
});

final externalImageUploadServiceProvider =
    Provider<ExternalImageUploadService>((ref) {
  return ExternalImageUploadService();
});

final forumAttachmentUploadServiceProvider =
    Provider<ForumAttachmentUploadService>((ref) {
  return ForumAttachmentUploadService(ref.watch(httpClientProvider));
});
