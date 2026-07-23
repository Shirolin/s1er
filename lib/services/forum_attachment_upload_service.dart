import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../config/env_config.dart';
import '../models/compose_image_upload_result.dart';
import '../models/forum_attachment_upload_info.dart';
import '../utils/forum_attachment_upload_info_parser.dart';
import 'http_client.dart';
import 'talker.dart';

/// Discuz 论坛附件上传（`misc.php?mod=swfupload` → aid → imagelist）。
class ForumAttachmentUploadService {
  ForumAttachmentUploadService(this._httpClient);

  final S1HttpClient _httpClient;

  /// 流浪图床同级上限；论坛另有额度，仍先做客户端保护。
  static const int maxBytes = 5 * 1024 * 1024;

  Future<ComposeImageUploadResult> upload({
    required Uint8List bytes,
    required String filename,
    required ForumAttachmentUploadInfo info,
    required String uid,
    required String referer,
  }) async {
    final safeName = filename.trim().isEmpty ? 'image.jpg' : filename.trim();
    if (bytes.isEmpty) {
      throw const ForumAttachmentUploadException('图片内容为空');
    }
    if (bytes.length > maxBytes) {
      throw ForumAttachmentUploadException(
        '图片过大（${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB），'
        '上限 ${maxBytes ~/ (1024 * 1024)} MB，请压缩后再试',
      );
    }
    if (!info.isValid) {
      throw const ForumAttachmentUploadException('无法获取论坛上传参数，请稍后重试');
    }
    if (uid.trim().isEmpty) {
      throw const ForumAttachmentUploadException('请先登录后再上传图片');
    }

    final uploadUrl = _resolveUploadUrl(info);
    // 对齐网页 / S1-Next：固定 WU_FILE_0，便于 imagelist ajaxtarget。
    const uploadId = 'WU_FILE_0';
    final mime = _contentTypeFor(safeName);
    final fileType = _fileExtension(safeName);

    try {
      final formData = FormData.fromMap({
        'uid': uid.trim(),
        'hash': info.hash,
        'type': mime,
        'id': uploadId,
        'size': bytes.length.toString(),
        'filetype': fileType,
        'Filedata': MultipartFile.fromBytes(
          bytes,
          filename: safeName,
          contentType: DioMediaType.parse(mime),
        ),
      });

      final origin = Uri.parse(ApiConfig.baseUrl).origin;
      final response = await _httpClient.post(
        uploadUrl,
        data: formData,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Origin': origin,
            'Referer': referer,
            'Accept': '*/*',
          },
          extra: const {
            's1DesktopUa': true,
            's1SkipFormhash': true,
          },
          sendTimeout: const Duration(
            seconds: EnvConfig.imageUploadTimeoutSeconds,
          ),
          receiveTimeout: const Duration(
            seconds: EnvConfig.imageUploadTimeoutSeconds,
          ),
        ),
      );

      final body = response.data?.toString() ?? '';
      final aid = parseForumAttachmentUploadAid(body);
      if (aid == null) {
        final brief = body.replaceAll(RegExp(r'\s+'), ' ').trim();
        talker.warning(
          'Forum attachment upload rejected: '
          '${brief.length > 200 ? '${brief.substring(0, 200)}…' : brief}',
        );
        throw ForumAttachmentUploadException(
          forumAttachmentUploadErrorMessage(body),
        );
      }

      var previewUrl = await _fetchPreviewUrl(
        aid: aid,
        fid: info.fid,
        ajaxTarget: uploadId,
      );
      previewUrl ??= parseForumAttachmentUploadPreviewUrl(body);

      return ComposeImageUploadResult(
        insertTag: '[attachimg]$aid[/attachimg]',
        label: safeName,
        previewUrl: previewUrl,
        aid: aid,
      );
    } on ForumAttachmentUploadException {
      rethrow;
    } on DioException catch (e, st) {
      talker.handle(e, st, 'Forum attachment upload failed');
      throw ForumAttachmentUploadException(_messageForDio(e));
    } catch (e, st) {
      talker.handle(e, st, 'Forum attachment upload failed');
      throw const ForumAttachmentUploadException('图片上传失败，请稍后重试');
    }
  }

  Future<String?> _fetchPreviewUrl({
    required String aid,
    required String fid,
    required String ajaxTarget,
  }) async {
    Future<String?> tryList(String url) async {
      final response = await _httpClient.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'X-Requested-With': 'XMLHttpRequest'},
          extra: const {'s1DesktopUa': true},
        ),
      );
      final map =
          parseForumAttachmentImageList(response.data?.toString() ?? '');
      return map[aid];
    }

    try {
      // 对齐 S1-Next：优先 attachlist。
      final fromAttachList = await tryList(
        ApiConfig.forumAttachmentImageListUrl(
          aids: aid,
          fid: fid,
          ajaxTarget: ajaxTarget,
        ),
      );
      if (fromAttachList != null && fromAttachList.isNotEmpty) {
        return fromAttachList;
      }
      return await tryList(
        ApiConfig.forumAttachmentImageListFallbackUrl(
          aids: aid,
          fid: fid,
          ajaxTarget: ajaxTarget,
        ),
      );
    } catch (e, st) {
      talker.handle(e, st, 'Forum attachment imagelist failed');
      return null;
    }
  }

  static String _resolveUploadUrl(ForumAttachmentUploadInfo info) {
    final raw = info.uploadUrl?.trim();
    if (raw == null || raw.isEmpty) {
      // 无页内 URL：桌面路径；触屏凭据通常已带 uploadurl。
      return ApiConfig.forumAttachmentUploadUrl(fid: info.fid);
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) {
      return '${Uri.parse(ApiConfig.baseUrl).origin}$raw';
    }
    return '${ApiConfig.baseUrl}/$raw';
  }

  static String _messageForDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '图片上传超时，请换较小文件或稍后重试';
      case DioExceptionType.connectionError:
        return '无法连接论坛，请检查网络或本时代理是否已启动';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final data = e.response?.data?.toString() ?? '';
        if (data.trim().isNotEmpty) {
          final aid = parseForumAttachmentUploadAid(data);
          if (aid == null) return forumAttachmentUploadErrorMessage(data);
        }
        return '图片上传失败（HTTP ${code ?? 'error'}）';
      case DioExceptionType.cancel:
        return '图片上传已取消';
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return '图片上传失败，请稍后重试';
    }
  }

  static String _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }

  static String _fileExtension(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot < 0 || dot == lower.length - 1) return 'jpg';
    return lower.substring(dot + 1);
  }
}

class ForumAttachmentUploadException implements Exception {
  const ForumAttachmentUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
