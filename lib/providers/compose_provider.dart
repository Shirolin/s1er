import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../models/quote_info.dart';
import '../models/reply_submit_result.dart';
import '../models/new_thread_form_info.dart';
import '../models/new_thread_submit_result.dart';
import '../models/edit_post_form_info.dart';
import '../models/edit_post_submit_result.dart';
import '../services/external_image_upload_service.dart';
import '../utils/quote_builder.dart';
import 'api_service_provider.dart';

/// 回复编排：预取官方引用字段 + 提交 `module=sendreply`。
class ComposeController {
  ComposeController(this._ref);

  final Ref _ref;

  Future<QuoteInfo?> prefetchQuote({
    required String tid,
    required String pid,
  }) {
    return _ref.read(apiServiceProvider).fetchQuoteInfo(tid: tid, pid: pid);
  }

  /// [message] 只含用户正文（可含 `[img]`），不含客户端拼的 `[quote]`。
  ///
  /// 有 [quotedPost] 时，用网页同款完整 `[quote][url=findpost]…` 作为
  /// `noticetrimstr`（保留官方 `noticeauthor`），替代 helper 缩略 `[post]`。
  Future<ReplySubmitResult> submitReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    Post? quotedPost,
  }) {
    final effectiveQuote = quoteInfoForSubmit(
      quoteInfo: quoteInfo,
      quotedPost: quotedPost,
      tid: tid,
    );
    return _ref.read(apiServiceProvider).sendReply(
          tid: tid,
          fid: fid,
          message: message,
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
  }) {
    return _ref.read(apiServiceProvider).submitNewThread(
          fid: fid,
          subject: subject,
          message: message,
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
  }) {
    return _ref.read(apiServiceProvider).submitEditPost(
          fid: fid,
          tid: tid,
          pid: pid,
          isFirst: isFirst,
          subject: subject,
          message: message,
          typeId: typeId,
          readPerm: readPerm,
          baseline: baseline,
        );
  }

  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
  }) {
    return _ref.read(externalImageUploadServiceProvider).upload(
          bytes: Uint8List.fromList(bytes),
          filename: filename,
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
