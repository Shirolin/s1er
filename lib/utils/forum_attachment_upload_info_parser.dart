import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import '../config/api_config.dart';
import '../models/forum_attachment_upload_info.dart';

/// 从 Discuz 发帖/回复/编辑 HTML 解析论坛附件上传凭据。
///
/// 顺序对齐 S1-Next：表单 `hash`/`uid`/`fid`/`operation=upload`，
/// 再回退脚本里的 `post_params` / `upload_url`。
ForumAttachmentUploadInfo? parseForumAttachmentUploadInfo(
  String html, {
  String? fallbackFid,
}) {
  final unwrapped = unwrapAjaxHtml(html);
  if (unwrapped.trim().isEmpty) return null;

  try {
    final document = parse(unwrapped);
    final fromForm = _fromForm(document, fallbackFid: fallbackFid);
    if (fromForm != null) return fromForm;
    return _fromScripts(document, fallbackFid: fallbackFid);
  } catch (_) {
    return null;
  }
}

/// 解析上传响应：纯数字 aid，或 `DISCUZUPLOAD|0|{aid}|…`。
String? parseForumAttachmentUploadAid(String response) {
  final result = response.trim();
  if (result.isEmpty) return null;
  final numeric = int.tryParse(result);
  if (numeric != null && numeric > 0) return numeric.toString();

  final parts = result.split('|');
  if (parts.length >= 3 &&
      parts[0] == 'DISCUZUPLOAD' &&
      parts[1] == '0') {
    final aid = int.tryParse(parts[2].trim());
    if (aid != null && aid > 0) return aid.toString();
  }
  return null;
}

/// 把 Discuz 上传失败响应映射成可读中文。
String forumAttachmentUploadErrorMessage(String response) {
  final result = response.trim();
  if (result.isEmpty) return '图片上传失败，请稍后重试';
  final parts = result.split('|');
  String reason;
  if (parts.length >= 3 && parts[0] == 'DISCUZUPLOAD') {
    // DISCUZUPLOAD|{status}|{reason|aid}|…
    reason = parts[2].trim();
  } else if (parts.length >= 2) {
    reason = parts.skip(1).firstWhere(
          (p) => p.isNotEmpty && p != '0',
          orElse: () => '',
        );
  } else {
    reason = result;
  }
  switch (reason) {
    case 'ban':
      return '附件类型被禁止';
    case 'perday':
      return '今日附件上传额度不足';
    case '-1':
      return '图片上传失败，请稍后重试';
    case '':
      return '图片上传失败，请稍后重试';
    default:
      if (int.tryParse(reason) != null) {
        return '图片上传失败，请稍后重试';
      }
      final short = reason.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (short.length > 80) {
        return '图片上传失败：${short.substring(0, 80)}';
      }
      return '图片上传失败：$short';
  }
}

/// 从 imagelist / attachlist HTML 提取 `aid → 预览 URL`。
Map<String, String> parseForumAttachmentImageList(String html) {
  final unwrapped = unwrapAjaxHtml(html);
  if (unwrapped.trim().isEmpty) return const {};
  final map = <String, String>{};
  try {
    final document = parse(unwrapped);
    for (final img in document.querySelectorAll('img')) {
      final id = img.id.trim();
      String? aid;
      if (id.startsWith('image_')) {
        aid = id.substring('image_'.length).trim();
      } else if (id.startsWith('aimg_')) {
        aid = id.substring('aimg_'.length).trim();
      }
      if (aid == null || aid.isEmpty) continue;
      final src = img.attributes['src']?.trim() ?? '';
      if (src.isEmpty) continue;
      map[aid] = absolutizeForumUrl(src);
    }
    for (final el in document.querySelectorAll('[aid]')) {
      final aid = el.attributes['aid']?.trim() ?? '';
      if (aid.isEmpty || map.containsKey(aid)) continue;
      final img = el.localName == 'img' ? el : el.querySelector('img');
      final src = img?.attributes['src']?.trim() ?? '';
      if (src.isEmpty) continue;
      map[aid] = absolutizeForumUrl(src);
    }
  } catch (_) {
    // 预览失败不影响上传主流程。
  }
  return map;
}

/// 供测试与其它解析复用。
String unwrapAjaxHtml(String body) {
  final trimmed = body.trim();
  final cdata = RegExp(
    r'<!\[CDATA\[([\s\S]*?)\]\]>',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (cdata != null) return cdata.group(1) ?? trimmed;
  return trimmed;
}

/// 相对论坛路径补全为绝对 URL。
String absolutizeForumUrl(String src) {
  final trimmed = src.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  final base = Uri.parse(ApiConfig.baseUrl);
  if (trimmed.startsWith('/')) {
    return '${base.scheme}://${base.host}$trimmed';
  }
  return '${ApiConfig.baseUrl}/$trimmed';
}

ForumAttachmentUploadInfo? _fromForm(
  Document document, {
  String? fallbackFid,
}) {
  final hash =
      document.querySelector('input[name="hash"]')?.attributes['value']?.trim();
  if (hash == null || hash.isEmpty) return null;

  final uid =
      document.querySelector('input[name="uid"]')?.attributes['value']?.trim();
  final uploadUrl = document
      .querySelector('form[action*="operation=upload"]')
      ?.attributes['action']
      ?.trim();
  final fidInput =
      document.querySelector('input[name="fid"]')?.attributes['value']?.trim();
  final formhash = document
      .querySelector('input[name="formhash"]')
      ?.attributes['value']
      ?.trim();

  final fid = (fidInput != null && fidInput.isNotEmpty)
      ? fidInput
      : (fidFromUploadUrl(uploadUrl) ?? fallbackFid);
  if (fid == null || fid.isEmpty) return null;

  return ForumAttachmentUploadInfo(
    hash: hash,
    fid: fid,
    uid: (uid != null && uid.isNotEmpty) ? uid : null,
    uploadUrl: (uploadUrl != null && uploadUrl.isNotEmpty) ? uploadUrl : null,
    formhash: (formhash != null && formhash.isNotEmpty) ? formhash : null,
  );
}

ForumAttachmentUploadInfo? _fromScripts(
  Document document, {
  String? fallbackFid,
}) {
  for (final script in document.querySelectorAll('script')) {
    final content = script.text;
    if (content.isEmpty) continue;
    final postParams = _extractJsObjectProperty(content, 'post_params');
    if (postParams == null) continue;
    final hash = _jsonStringField(postParams, 'hash');
    if (hash == null || hash.isEmpty) continue;
    final uid = _jsonStringField(postParams, 'uid');
    final uploadUrl = _extractJsStringProperty(content, 'upload_url');
    final fid = _jsonStringField(postParams, 'fid') ??
        fidFromUploadUrl(uploadUrl) ??
        fallbackFid;
    if (fid == null || fid.isEmpty) continue;
    return ForumAttachmentUploadInfo(
      hash: hash,
      fid: fid,
      uid: (uid != null && uid.isNotEmpty) ? uid : null,
      uploadUrl: uploadUrl,
      formhash: null,
    );
  }
  return null;
}

String? _extractJsObjectProperty(String script, String property) {
  final pattern = RegExp(
    '$property\\s*[:=]\\s*(\\{[\\s\\S]*?\\})',
    caseSensitive: false,
  );
  return pattern.firstMatch(script)?.group(1);
}

String? _extractJsStringProperty(String script, String property) {
  final pattern = RegExp(
    '''$property\\s*[:=]\\s*['"]([^'"]+)['"]''',
    caseSensitive: false,
  );
  return pattern.firstMatch(script)?.group(1)?.trim();
}

String? _jsonStringField(String objectLiteral, String key) {
  final pattern = RegExp(
    '''['"]?$key['"]?\\s*:\\s*['"]([^'"]*)['"]''',
    caseSensitive: false,
  );
  final value = pattern.firstMatch(objectLiteral)?.group(1)?.trim();
  return (value != null && value.isNotEmpty) ? value : null;
}

/// 从上传 URL 取 fid。
String? fidFromUploadUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final absolute = url.startsWith('http')
      ? url
      : (url.startsWith('/')
          ? '${Uri.parse(ApiConfig.baseUrl).origin}$url'
          : '${ApiConfig.baseUrl}/$url');
  return Uri.tryParse(absolute)?.queryParameters['fid']?.trim();
}
