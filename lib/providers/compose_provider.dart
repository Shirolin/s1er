import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quote_info.dart';
import '../models/reply_submit_result.dart';
import '../models/new_thread_form_info.dart';
import '../models/new_thread_submit_result.dart';
import '../services/external_image_upload_service.dart';
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
  Future<ReplySubmitResult> submitReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
  }) {
    return _ref.read(apiServiceProvider).sendReply(
          tid: tid,
          fid: fid,
          message: message,
          quoteInfo: quoteInfo,
          noticeAuthorMsg: message,
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
