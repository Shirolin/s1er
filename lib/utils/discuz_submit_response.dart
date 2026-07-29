import 'dart:convert';

import '../models/reply_submit_result.dart';
import 'discuz_message.dart';

/// Discuz 发帖 / 回帖提交响应的统一解析（Mobile JSON + Web Ajax XML/HTML）。
///
/// 设计原则：
/// 1. 先判成功（succeedhandle、跳转、成功文案），再判错误；
/// 2. 成功文案绝不走 [ReplySubmitResult.rejected]；
/// 3. 无法确认时返回 [ReplySubmitResult.uncertain]，避免误导向用户重试。
abstract final class DiscuzSubmitResponse {
  /// Dio 在未设 [ResponseType.plain] 时偶发给出 `List<int>`。
  static String coerceBody(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is List<int>) {
      return utf8.decode(data, allowMalformed: true);
    }
    return data.toString();
  }

  static String unwrapAjaxHtml(String body) {
    final cdataMatch = RegExp(
      r'<!\[CDATA\[(.*)\]\]>',
      dotAll: true,
    ).firstMatch(body);
    return cdataMatch?.group(1) ?? body;
  }

  /// 解析 Web Ajax 回帖响应。
  static ReplySubmitResult parseReplyAjaxBody(dynamic body) {
    final html = unwrapAjaxHtml(coerceBody(body)).trim();
    if (html.isEmpty) {
      return const ReplySubmitResult.uncertain('服务器未返回回复结果，请刷新主题确认');
    }

    final ids = _extractPostIds(html);

    if (_hasSucceedHandleCall(html)) {
      return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
    }

    if (_hasViewthreadRedirect(html)) {
      return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
    }

    if (RegExp(
      'http-equiv\\s*=\\s*["\']?refresh["\']?[^>]*(?:mod=viewthread|tid=\\d+)',
      caseSensitive: false,
    ).hasMatch(html)) {
      return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
    }

    if (RegExp(
      r'post_reply_succeed|post_newthread_succeed',
      caseSensitive: false,
    ).hasMatch(html)) {
      return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
    }

    final errorFromHandler = _extractErrorMessage(html);
    if (errorFromHandler != null && errorFromHandler.isNotEmpty) {
      if (looksLikePostSuccessMessage(errorFromHandler)) {
        return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
      }
      return ReplySubmitResult.rejected(errorFromHandler);
    }

    final showMessage = RegExp(
      r"showmessage\('([^']*)'",
    ).firstMatch(html)?.group(1)?.trim();
    if (showMessage != null && showMessage.isNotEmpty) {
      if (looksLikePostSuccessMessage(showMessage)) {
        return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
      }
      return ReplySubmitResult.rejected(showMessage);
    }

    final alertMessage =
        RegExp(r"alert\('([^']*)'\)").firstMatch(html)?.group(1);
    if (alertMessage != null && alertMessage.isNotEmpty) {
      if (looksLikePostSuccessMessage(alertMessage)) {
        return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
      }
      return ReplySubmitResult.rejected(alertMessage);
    }

    final messageText = extractMessagetextParagraph(html);
    if (messageText != null) {
      if (looksLikePostSuccessMessage(messageText)) {
        return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
      }
      return ReplySubmitResult.rejected(messageText);
    }

    if (looksLikePostSuccessMessage(html) &&
        RegExp(r'(?:mod=viewthread|tid=\d+)').hasMatch(html)) {
      return ReplySubmitResult(pid: ids.pid, tid: ids.tid);
    }

    return const ReplySubmitResult.uncertain(
      '回复状态不明确，请刷新主题页确认是否已发出',
    );
  }

  /// 解析 Mobile `module=sendreply` JSON（或回落 Ajax / 裸 key）。
  static ReplySubmitResult parseSendReplyMobileBody(dynamic data) {
    final raw = coerceBody(data);
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('{')) {
      try {
        return parseSendReplyMobileBody(jsonDecode(trimmed));
      } catch (_) {
        // fall through
      }
    }
    if (trimmed.startsWith('<') ||
        trimmed.contains('succeedhandle_') ||
        trimmed.contains('errorhandle_')) {
      return parseReplyAjaxBody(raw);
    }
    if (looksLikeDiscuzMessageKey(trimmed) || trimmed.startsWith('mobile:')) {
      return ReplySubmitResult.rejected(
        friendlyDiscuzApiError(messageval: trimmed),
      );
    }

    if (data is! Map) {
      if (raw.trim().isEmpty) {
        return const ReplySubmitResult.uncertain('服务器未返回回复结果，请刷新主题确认');
      }
      return parseReplyAjaxBody(raw);
    }

    final map = Map<String, dynamic>.from(data);
    if (map['error'] != null) {
      return ReplySubmitResult.rejected(
        friendlyDiscuzApiError(
          messageval: map['error']?.toString(),
          messagestr: map['error']?.toString(),
        ),
      );
    }

    final message = map['Message'];
    String? messageval;
    String? messagestr;
    if (message is Map) {
      messageval = message['messageval']?.toString();
      messagestr = message['messagestr']?.toString();
    }

    if (isPostSuccessStatus(messageval, messagestr)) {
      final variables = map['Variables'];
      String? pid;
      String? tid;
      if (variables is Map) {
        pid = variables['pid']?.toString();
        tid = variables['tid']?.toString();
        if (pid != null && pid.isEmpty) pid = null;
        if (tid != null && tid.isEmpty) tid = null;
      }
      return ReplySubmitResult(pid: pid, tid: tid);
    }

    final friendly = friendlyDiscuzApiError(
      messageval: messageval,
      messagestr: messagestr,
      fallback: '回复失败，请稍后重试',
    );
    if (looksLikePostSuccessMessage(friendly) ||
        looksLikePostSuccessMessage(messagestr ?? '')) {
      final variables = map['Variables'];
      String? pid;
      String? tid;
      if (variables is Map) {
        pid = variables['pid']?.toString();
        tid = variables['tid']?.toString();
        if (pid != null && pid.isEmpty) pid = null;
        if (tid != null && tid.isEmpty) tid = null;
      }
      return ReplySubmitResult(pid: pid, tid: tid);
    }

    return ReplySubmitResult.rejected(friendly);
  }

  /// Discuz Ajax handler 第二参数文案（quote-aware 切参）。
  static String? extractHandlerMessage(
    String html, {
    required String handlerPrefix,
    required int messageIndex,
  }) {
    final match = RegExp(
      '$handlerPrefix[^\\(]*\\((.*)\\)',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    final params = _splitAjaxParams(match.group(1) ?? '');
    if (params.length <= messageIndex) return '';
    return _stripQuotes(params[messageIndex]);
  }

  static String? extractMessagetextParagraph(String html) {
    final message = RegExp(
      r'''id=["']messagetext["'][^>]*>.*?<p>([^<]+)''',
      dotAll: true,
    ).firstMatch(html)?.group(1)?.trim();
    if (message != null && message.isNotEmpty) return message;
    final jump = RegExp(
      r'''class=["'][^"']*jump_c[^"']*["'][^>]*>\s*<p>([^<]+)''',
      dotAll: true,
    ).firstMatch(html)?.group(1)?.trim();
    return jump == null || jump.isEmpty ? null : jump;
  }

  static bool isPostSuccessStatus(String? messageval, [String? messagestr]) {
    final val = normalizeDiscuzMessageKey(messageval);
    if (val.contains('succeed') ||
        val.endsWith('_success') ||
        val == 'do_success') {
      return true;
    }
    return looksLikePostSuccessMessage(messagestr ?? '');
  }

  /// 发帖 / 回帖成功提示文案（含 S1 触屏页常见句式）。
  static bool looksLikePostSuccessMessage(String text) {
    if (text.isEmpty) return false;
    const needles = [
      '回复发布成功',
      '回复成功',
      '回复已发表',
      '发帖成功',
      '发表成功',
      '发布成功',
      '帖子发布成功',
      '主题发布成功',
      '现在将转入主题页',
      '转入主题页',
      'post_reply_succeed',
      'post_newthread_succeed',
    ];
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }

  static ({String? pid, String? tid}) extractPostIds(String html) =>
      _extractPostIds(html);

  static String? _extractErrorMessage(String html) {
    final replyErr = RegExp(
      r"errorhandle_reply\('([^']*)',\s*'([^']*)'\)",
    ).firstMatch(html);
    if (replyErr != null) {
      final first = replyErr.group(1)?.trim() ?? '';
      final second = replyErr.group(2)?.trim() ?? '';
      final msg = first.isNotEmpty ? first : second;
      if (msg.isNotEmpty) return msg;
    }

    final postformErr = RegExp(
      r"errorhandle_postform\('([^']*)'",
    ).firstMatch(html)?.group(1)?.trim();
    if (postformErr != null && postformErr.isNotEmpty) return postformErr;

    final generic = extractHandlerMessage(
      html,
      handlerPrefix: 'errorhandle_',
      messageIndex: 0,
    );
    if (generic != null && generic.isNotEmpty) return generic;
    return null;
  }

  static String? extractPostId(String html, String key) =>
      _extractPostId(html, key);

  static ({String? pid, String? tid}) _extractPostIds(String html) {
    return (
      pid: _extractPostId(html, 'pid'),
      tid: _extractPostId(html, 'tid'),
    );
  }

  static String? _extractPostId(String html, String key) {
    final fromMeta =
        RegExp("$key\\s*:\\s*'(\\d+)'").firstMatch(html)?.group(1) ??
            RegExp('$key\\s*:\\s*"(\\d+)"').firstMatch(html)?.group(1);
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return switch (key) {
      'tid' => RegExp(r'[?&]tid=(\d+)').firstMatch(html)?.group(1) ??
          RegExp(r'[?&]ptid=(\d+)').firstMatch(html)?.group(1),
      'pid' => RegExp(r'[?&]pid=(\d+)').firstMatch(html)?.group(1) ??
          RegExp(r'#pid(\d+)').firstMatch(html)?.group(1),
      _ => null,
    };
  }

  /// 仅匹配真实 `succeedhandle_*(` 调用，排除仅有 `typeof succeedhandle_` 的定义。
  static bool _hasSucceedHandleCall(String html) {
    return RegExp(r'succeedhandle_[^(]*\(', caseSensitive: false)
        .hasMatch(html);
  }

  static bool _hasViewthreadRedirect(String html) {
    return RegExp(
      r'(?:window\.location|location\.href)\s*=\s*[^;]*(?:mod=viewthread|goto=findpost)',
      caseSensitive: false,
    ).hasMatch(html);
  }

  static List<String> _splitAjaxParams(String raw) {
    final params = <String>[];
    final buffer = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch == "'" && (i == 0 || raw[i - 1] != r'\')) {
        inQuote = !inQuote;
        buffer.write(ch);
        continue;
      }
      if (ch == ',' && !inQuote) {
        params.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }
    final last = buffer.toString().trim();
    if (last.isNotEmpty || params.isNotEmpty) {
      params.add(last);
    }
    return params;
  }

  static String _stripQuotes(String value) {
    var msg = value.trim();
    if (msg.startsWith("'")) msg = msg.substring(1);
    if (msg.endsWith("'")) msg = msg.substring(0, msg.length - 1);
    return msg.replaceAll(r"\'", "'").trim();
  }
}
