/// Discuz 响应解析（纯）：把服务端 JSON / HTML / XML 转换为 `models/` 数据模型。
///
/// 本模块只依赖 `models/*`、纯 utils、`config/api_config`（URL 拼接常量，无 I/O）
/// 与全局日志 `talker`（仅 `warning` 诊断；`compute` 入口 `parsePostList` 自身不打日志，
/// HTML 救援路径的日志落在调用方 isolate 的 talker 历史里，不影响解析结果）。
/// 它可安全地跑在 isolate 中（`compute` 的入口）。
///
/// 传输、限速、Cookie/formhash 与协议判定仍归 `ApiService` /
/// `S1HttpClient`；见 `docs/adr/0001-parser-transport-seam.md`。
library;

import 'dart:convert';

import 'package:html/parser.dart' show parse;

import '../config/api_config.dart';
import '../models/app_exceptions.dart';
import '../models/edit_post_form_info.dart';
import '../models/edit_post_submit_result.dart';
import '../models/favorite_item.dart';
import '../models/forum_category.dart';
import '../models/message_list_result.dart';
import '../models/new_thread_form_info.dart';
import '../models/new_thread_submit_result.dart';
import '../models/notice_item.dart';
import '../models/pm_send_result.dart';
import '../models/poll.dart';
import '../models/post.dart';
import '../models/private_message.dart';
import '../models/private_message_item.dart';
import '../models/rate_form.dart';
import '../models/reply_submit_result.dart';
import '../models/report_form.dart';
import '../models/search_result.dart';
import '../models/thread.dart';
import '../models/user_space_item.dart';
import '../utils/compose_img_tags.dart';
import '../utils/discuz_message.dart';
import '../utils/discuz_submit_response.dart';
import '../utils/forum_attachment_upload_info_parser.dart';
import '../utils/html_entities.dart';
import '../utils/read_perm_options.dart';
import 'talker.dart';

/// Discuz 响应解析器：纯函数集合，无 I/O；日志经 `talker`（见模块头注释）。
abstract final class DiscuzParser {
  // ===========================================================================
  // 响应外壳 / 协议工具（纯）
  // ===========================================================================

  /// 从 HTML 中救援被包裹的 API JSON；形状不像 API 响应时返回 `null`。
  ///
  /// 键名判定收紧为结构化校验：`Variables` 必须是 Map（Discuz 响应的
  /// Variables 恒为对象；攻击者可拟制的裸键名不足以把任意 JSON 骗成成功
  /// 数据）。`error` 键只走向失败/报错文案，保留宽松判定是安全的。
  static Map<String, dynamic>? rescueJsonFromHtml(String html) {
    final start = html.indexOf('{');
    final end = html.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(html.substring(start, end + 1));
      if (decoded is Map<String, dynamic> &&
          (decoded['Variables'] is Map || decoded.containsKey('error'))) {
        // 救援通道本应低频命中；记录便于观测误判（把非 API HTML 里的
        // 花括号区间当成了成功响应）。
        talker.warning(
          '[api-rescue] HTML 响应中救援出 JSON：'
          'keys=${decoded.keys.take(8).join(',')}',
        );
        return decoded;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// Mobile API 在无业务数据时返回的 `error` 文案（如维护公告）。
  /// 依次读取顶层 `error` 与 `Variables.error`（S1-Orange 亦识别后者）。
  static String? extractApiErrorMessage(Map<String, dynamic> json) {
    final top = _cleanServerMessage(json['error']);
    if (top != null) return top;
    final variables = json['Variables'];
    if (variables is Map) return _cleanServerMessage(variables['error']);
    return null;
  }

  /// Discuz 标准 `Message.messagestr`：当其 `messageval` 非成功语义时，
  /// 即服务器对「为什么没有数据」的官方解释（对齐 S1-Next Result.kt
  /// 的 `_succeed` / `_success` 后缀判定）。
  static String? extractDiscuzMessageError(Map<String, dynamic> json) {
    final message = json['Message'];
    if (message is! Map) return null;
    final messageval = message['messageval']?.toString() ?? '';
    final succeeded = messageval.endsWith('_succeed') ||
        messageval.endsWith('_success') ||
        messageval.endsWith('_succeed_mobile');
    if (succeeded) return null;
    final messagestr = message['messagestr']?.toString().trim() ?? '';
    if (messagestr.isEmpty || messagestr == 'to_login') return null;
    return messagestr;
  }

  static String? _cleanServerMessage(dynamic raw) {
    if (raw == null) return null;
    final message = raw.toString().trim();
    if (message.isEmpty || message == 'to_login') return null;
    return message;
  }

  /// `_unwrapAjaxHtml`：剥掉 ajax 包裹，取出内层 HTML。
  static String _unwrapAjaxHtml(String body) =>
      DiscuzSubmitResponse.unwrapAjaxHtml(body);

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList();
    return [];
  }

  // ===========================================================================
  // 帖子 / 主题
  // ===========================================================================

  static bool hasThreadDetailData(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return false;
    if (variables['thread'] is Map<String, dynamic>) return true;
    return parsePostList(json).isNotEmpty;
  }

  static Map<String, String> parseThreadTypes(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return {};
    final threadtypes = variables['threadtypes'] as Map<String, dynamic>?;
    if (threadtypes == null) return {};
    final types = threadtypes['types'] as Map<String, dynamic>?;
    if (types == null) return {};
    return types.map((k, v) => MapEntry(k, v.toString()));
  }

  /// 解析 `module=newthread` 的权限、分类与 formhash。
  static NewThreadFormInfo parseNewThreadForm(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final threadtypes = variables?['threadtypes'] as Map<String, dynamic>?;
    final types = threadtypes?['types'] as Map<String, dynamic>?;
    final parsedTypes = types == null
        ? const <String, String>{}
        : types.map((key, value) => MapEntry(key, value.toString()));
    final required = threadtypes?['required']?.toString() == '1';
    final formhash = variables?['formhash']?.toString();
    final message = json['Message'];
    final messageval =
        message is Map ? message['messageval']?.toString() : null;
    final messagestr =
        message is Map ? message['messagestr']?.toString() : null;
    final hasPermissionError = messageval != null &&
        messageval.isNotEmpty &&
        !messageval.contains('succeed');
    return NewThreadFormInfo(
      threadTypes: parsedTypes,
      typeRequired: required,
      formhash: formhash,
      error: hasPermissionError
          ? friendlyDiscuzApiError(
              messageval: messageval,
              messagestr: messagestr,
              fallback: '当前版块暂不可发帖',
            )
          : null,
    );
  }

  static List<Thread> parseThreadList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final threadList = variables?['forum_threadlist'] as List?;
    if (threadList == null) return [];
    final threadTypes = parseThreadTypes(json);
    return threadList.map((t) {
      final thread = Thread.fromJson(t as Map<String, dynamic>);
      if (thread.typeId != null &&
          thread.typeName == null &&
          threadTypes.containsKey(thread.typeId)) {
        return thread.copyWith(typeName: threadTypes[thread.typeId]);
      }
      return thread;
    }).toList();
  }

  static String? parseForumDisplayName(Map<String, dynamic> json) {
    final forum = json['Variables']?['forum'] as Map<String, dynamic>?;
    final name = forum?['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static int parseThreadListTotalPages(
    Map<String, dynamic> json, {
    required int currentPage,
    required int itemCount,
    required bool isFiltered,
  }) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return 1;
    final forum = variables['forum'] as Map<String, dynamic>?;
    int? totalThreads = int.tryParse(
      variables['threadcount']?.toString() ?? '',
    );
    totalThreads ??= int.tryParse(forum?['threadcount']?.toString() ?? '');
    if (!isFiltered) {
      totalThreads ??= int.tryParse(forum?['threads']?.toString() ?? '');
      totalThreads ??= int.tryParse(variables['threads']?.toString() ?? '');
    }
    final perPage = int.tryParse(variables['tpp']?.toString() ?? '') ?? 50;
    if (totalThreads != null && totalThreads > 0 && perPage > 0) {
      return (totalThreads / perPage).ceil();
    }
    if (perPage > 0 && itemCount >= perPage) return currentPage + 1;
    return currentPage < 1 ? 1 : currentPage;
  }

  static List<Post> parsePostList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final postList = variables?['postlist'] as List?;
    if (postList == null) return [];
    return postList
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// 解析 v4 `Variables.commentcount` 的键集合（本页有评分/点评的 pid）。
  ///
  /// v1 响应没有该字段。评分明细仍需按 pid 拉 `misc&action=viewratings`。
  static Set<String> parseRateMarkedPids(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final commentCount = variables?['commentcount'];
    if (commentCount is! Map) return const {};

    return commentCount.keys.map((key) => key.toString()).toSet();
  }

  /// 解析投票数据。非投票帖或缺 `special_poll` 时返回 null。
  static ThreadPoll? parsePoll(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return null;

    final thread = variables['thread'] as Map<String, dynamic>?;
    final special = int.tryParse(thread?['special']?.toString() ?? '') ?? 0;
    if (special != 1) return null;

    final pollData = variables['special_poll'];
    if (pollData is! Map<String, dynamic>) return null;

    return ThreadPoll.fromJson(pollData);
  }

  static List<ForumCategory> parseForumList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return [];

    // 1. 从 forumlist 构建 fid -> ForumCategory 查找表（含 sublist 子版块）
    final forumList = _asList(variables['forumlist']);
    final Map<String, ForumCategory> forumMap = {};
    for (final f in forumList) {
      final forum = ForumCategory.fromJson(f as Map<String, dynamic>);
      forumMap[forum.fid] = forum;
    }

    // 2. 从 catlist 构建分类树：每个分类的 forums 是 fid 字符串列表
    final catList = _asList(variables['catlist']);
    final List<ForumCategory> categories = [];
    for (final cat in catList) {
      final catMap = cat as Map<String, dynamic>;
      final catName = catMap['name']?.toString() ?? '';
      final catFid = catMap['fid']?.toString() ?? '';
      final forumIds =
          _asList(catMap['forums']).map((e) => e.toString()).toList();

      // 将 fid 列表转为 ForumCategory 子版块列表
      final subforums = forumIds
          .where((fid) => forumMap.containsKey(fid))
          .map((fid) => forumMap[fid]!)
          .toList();

      int totalThreads = 0;
      int totalPosts = 0;
      int totalTodayPosts = 0;
      for (final sub in subforums) {
        totalThreads += sub.threads;
        totalPosts += sub.posts;
        totalTodayPosts += sub.todayPosts;
      }

      categories.add(
        ForumCategory(
          fid: catFid,
          name: catName,
          description: '',
          threads: totalThreads,
          posts: totalPosts,
          todayPosts: totalTodayPosts,
          subforums: subforums,
        ),
      );
    }

    return categories;
  }

  static int? parseThreadReplies(Map<String, dynamic> json) {
    final variablesRaw = json['Variables'];
    if (variablesRaw is! Map) return null;
    final variables = Map<String, dynamic>.from(variablesRaw);
    final threadRaw = variables['thread'];
    if (threadRaw is! Map) return null;
    final thread = Map<String, dynamic>.from(threadRaw);
    return int.tryParse(thread['replies']?.toString() ?? '');
  }

  static ReplySubmitResult parseReplyResponse(dynamic body) =>
      DiscuzSubmitResponse.parseReplyAjaxBody(body);

  static ReplySubmitResult parseSendReplyResponse(dynamic data) =>
      DiscuzSubmitResponse.parseSendReplyMobileBody(data);

  static String? _extractReplyField(String meta, String key) {
    final single = RegExp("'?$key'?\\s*:\\s*'([^']*)'").firstMatch(meta);
    final singleValue = single?.group(1);
    if (singleValue != null && singleValue.isNotEmpty) return singleValue;
    final quoted = RegExp('"?$key"?\\s*:\\s*"([^"]*)"').firstMatch(meta);
    final quotedValue = quoted?.group(1);
    return quotedValue != null && quotedValue.isNotEmpty ? quotedValue : null;
  }

  /// 公开入口：从 ajax 元数据串中提取 `tid` / `pid` 等字段。
  static String? extractReplyField(String meta, String key) =>
      _extractReplyField(meta, key);

  // ===========================================================================
  // 表单 / 提交响应
  // ===========================================================================

  static EditPostFormInfo parseEditPostFormResponse(
    String body, {
    required bool isFirst,
  }) {
    final html = _unwrapAjaxHtml(body);
    if (html.trim().isEmpty) {
      return const EditPostFormInfo(error: '编辑表单为空，请稍后重试');
    }
    if (html.contains('id="loginform') ||
        html.contains("id='loginform") ||
        html.contains('name="login"')) {
      return const EditPostFormInfo(error: '请先登录');
    }

    final error = _extractEditPostError(html);
    if (error != null) return EditPostFormInfo(error: error);

    try {
      final document = parse(html);
      // PC 模板用 #e_textarea；触屏/手机模板用 #needmessage（客户端 UA 为
      // mobile 时 S1 会下发触屏页）。再兜底 name=message。
      final textarea = document.querySelector('textarea#e_textarea') ??
          document.querySelector('textarea#needmessage') ??
          document.querySelector('textarea[name="message"]');
      final message = textarea?.text ?? '';
      final subjectInput = document.querySelector('input#subject') ??
          document.querySelector('input#needsubject') ??
          document.querySelector('input[name="subject"]');
      final subject = subjectInput?.attributes['value'] ?? '';
      final formhash =
          document.querySelector('input[name="formhash"]')?.attributes['value'];
      final typeSelect = document.querySelector('select#typeid');
      final types = <String, String>{};
      String? selectedTypeId;
      for (final option in typeSelect?.querySelectorAll('option') ?? []) {
        final value = option.attributes['value']?.trim() ?? '';
        if (value.isEmpty) continue;
        types[value] = option.text.trim();
        if (option.attributes.containsKey('selected')) selectedTypeId = value;
      }
      final permissionSelect = document.querySelector('select#readperm');
      final permissionOptions = <({String value, String label})>[];
      String? selectedPermission;
      for (final option in permissionSelect?.querySelectorAll('option') ?? []) {
        final value = option.attributes['value']?.trim() ?? '';
        permissionOptions.add((value: value, label: option.text.trim()));
        if (option.attributes.containsKey('selected')) {
          selectedPermission = normalizeReadPermValue(value);
        }
      }
      final permissions = mergeReadPermOptions(permissionOptions);
      final special = int.tryParse(
            document
                    .querySelector('input[name="special"]')
                    ?.attributes['value'] ??
                '0',
          ) ??
          0;
      if (textarea == null || formhash == null || formhash.isEmpty) {
        return const EditPostFormInfo(error: '编辑表单缺少正文或验证串');
      }
      if (isFirst && special != 0) {
        return const EditPostFormInfo(error: '暂不支持编辑特殊主题首帖');
      }
      return EditPostFormInfo(
        subject: subject,
        message: message,
        threadTypes: types,
        selectedTypeId: selectedTypeId,
        readPermissions: permissions,
        selectedReadPermission: selectedPermission,
        formhash: formhash,
        isFirst: isFirst,
        special: special,
        attachImageUrls: extractAttachImageUrls(html),
        attachmentUploadInfo: parseForumAttachmentUploadInfo(html),
      );
    } catch (e) {
      return EditPostFormInfo(error: '编辑表单解析失败：$e');
    }
  }

  static String? _extractEditPostError(String html) {
    final message = RegExp(
      r'''id=["']messagetext["'][^>]*>.*?<p>([^<]+)''',
      dotAll: true,
    ).firstMatch(html)?.group(1)?.trim();
    if (message != null && message.isNotEmpty) return message;
    // 触屏提示页：<div class="jump_c"><p>…</p></div>
    final jump = RegExp(
      r'''class=["'][^"']*jump_c[^"']*["'][^>]*>\s*<p>([^<]+)''',
      dotAll: true,
    ).firstMatch(html)?.group(1)?.trim();
    if (jump != null && jump.isNotEmpty) return jump;
    final handler = RegExp(
      r"(?:errorhandle_[^\(]*|showmessage)\('([^']*)'",
    ).firstMatch(html)?.group(1)?.trim();
    return handler == null || handler.isEmpty ? null : handler;
  }

  static EditPostSubmitResult parseEditPostSubmitResponse(String body) {
    final html = _unwrapAjaxHtml(body).trim();
    if (html.isEmpty) {
      return const EditPostSubmitResult.uncertain('服务器未返回编辑结果');
    }
    // Ajax：`succeedhandle_postform`；语言包 key；触屏文案；msgforward 跳转脚本。
    if (RegExp(
      r'succeedhandle_|post_edit_succeed|编辑成功|帖子编辑成功',
      caseSensitive: false,
    ).hasMatch(html)) {
      return const EditPostSubmitResult.success(message: '编辑成功');
    }
    if (RegExp(
      r'(?:window\.location|location\.href)\s*=\s*\S*(?:mod=viewthread|tid=\d+)',
      caseSensitive: false,
    ).hasMatch(html)) {
      return const EditPostSubmitResult.success(message: '编辑成功');
    }
    if (RegExp(
      'http-equiv\\s*=\\s*["\']?refresh["\']?[^>]*(?:mod=viewthread|tid=\\d+)',
      caseSensitive: false,
    ).hasMatch(html)) {
      return const EditPostSubmitResult.success(message: '编辑成功');
    }
    final error = _extractEditPostError(html);
    if (error != null) return EditPostSubmitResult.rejected(error);
    final preview = html.length > 180 ? '${html.substring(0, 180)}…' : html;
    talker.warning('edit submit unrecognized body: $preview');
    return const EditPostSubmitResult.uncertain(
      '服务器返回未知结果，请先核对服务器内容，不要直接重复提交',
    );
  }

  static NewThreadSubmitResult parseNewThreadSubmitResponse(dynamic data) {
    if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('{')) {
        try {
          return parseNewThreadSubmitResponse(jsonDecode(trimmed));
        } catch (_) {}
      }
      if (looksLikeDiscuzMessageKey(trimmed) || trimmed.startsWith('mobile:')) {
        return NewThreadSubmitResult(
          error: friendlyDiscuzApiError(messageval: trimmed),
        );
      }
      return const NewThreadSubmitResult(error: '服务器返回未知响应');
    }
    if (data is! Map) {
      return const NewThreadSubmitResult(error: '服务器返回未知响应');
    }
    final map = Map<String, dynamic>.from(data);
    final message = map['Message'];
    final messageval =
        message is Map ? message['messageval']?.toString() : null;
    final messagestr =
        message is Map ? message['messagestr']?.toString() : null;
    if (messageval != null && messageval.contains('succeed')) {
      final variables = map['Variables'];
      final tid = variables is Map ? variables['tid']?.toString() : null;
      final pid = variables is Map ? variables['pid']?.toString() : null;
      if (tid == null || tid.isEmpty) {
        return const NewThreadSubmitResult(error: '服务器未返回新主题编号');
      }
      return NewThreadSubmitResult(tid: tid, pid: pid);
    }
    return NewThreadSubmitResult(
      error: friendlyDiscuzApiError(
        messageval: messageval,
        messagestr: messagestr,
        fallback: '发帖失败，请稍后重试',
      ),
    );
  }

  /// 网页发帖成功：`succeedhandle_*` 里带 tid。
  static NewThreadSubmitResult? parseWebNewThreadSubmitResponse(String xml) {
    final body = _unwrapAjaxHtml(DiscuzSubmitResponse.coerceBody(xml)).trim();
    if (body.isEmpty) return null;

    if (RegExp(r'succeedhandle_', caseSensitive: false).hasMatch(body)) {
      final detailed = RegExp(
        r"succeedhandle_[^(]*\('([^']*)',\s*'([^']*)'(?:,\s*\{([^}]*)\})?\)",
      ).firstMatch(body);
      if (detailed != null) {
        final meta = detailed.group(3) ?? '';
        final tid = _extractReplyField(meta, 'tid') ??
            DiscuzSubmitResponse.extractPostId(body, 'tid');
        final pid = _extractReplyField(meta, 'pid') ??
            DiscuzSubmitResponse.extractPostId(body, 'pid');
        if (tid != null && tid.isNotEmpty) {
          return NewThreadSubmitResult(tid: tid, pid: pid);
        }
      }
      final tid = DiscuzSubmitResponse.extractPostId(body, 'tid');
      if (tid != null && tid.isNotEmpty) {
        return NewThreadSubmitResult(
          tid: tid,
          pid: DiscuzSubmitResponse.extractPostId(body, 'pid'),
        );
      }
    }
    final errorMatch = RegExp(
      r"errorhandle_[^(]*\('([^']*)'",
    ).firstMatch(body);
    if (errorMatch != null) {
      final msg = errorMatch.group(1)?.trim();
      if (msg != null && msg.isNotEmpty) {
        return NewThreadSubmitResult(error: msg);
      }
    }
    return null;
  }

  // ===========================================================================
  // 投票 / 评分 / 举报
  // ===========================================================================

  static String? parsePollVoteResponse(String body) {
    if (body.contains('thread_poll_succeed') ||
        body.contains('pollvote_succeed') ||
        body.contains('投票成功') ||
        (body.contains('window.location.href') &&
            body.contains('viewthread'))) {
      return null;
    }

    final successMatch = RegExp(
      r"succeedhandle_pollvote\('([^']*)'",
    ).firstMatch(body);
    if (successMatch != null) return null;

    final errorMatch = RegExp(
      r"errorhandle_pollvote\('([^']*)',\s*'([^']*)'\)",
    ).firstMatch(body);
    if (errorMatch != null) {
      return errorMatch.group(1)?.isNotEmpty == true
          ? errorMatch.group(1)
          : errorMatch.group(2);
    }

    final showMessageMatch = RegExp(
      r"showmessage\('([^']*)'",
    ).firstMatch(body);
    if (showMessageMatch != null) {
      return showMessageMatch.group(1);
    }

    final alertMatch = RegExp(r"alert\('([^']*)'\)").firstMatch(body);
    if (alertMatch != null) return alertMatch.group(1);

    if (body.trim().isEmpty) {
      return '投票请求无响应，请检查是否已登录或已投过票';
    }

    return '服务器返回未知响应';
  }

  static String? extractMessagetextError(String body) {
    final messagetextMatch = RegExp(
      r'''id=["']messagetext["'][^>]*>.*?<p>([^<]+)''',
      dotAll: true,
    ).firstMatch(body);
    if (messagetextMatch != null) {
      final text = messagetextMatch.group(1)?.trim();
      if (text != null && text.isNotEmpty) return text;
    }

    final errorhandleMatch = RegExp(
      r"errorhandle_rate\('([^']*)',\s*'([^']*)'\)",
    ).firstMatch(body);
    if (errorhandleMatch != null) {
      return errorhandleMatch.group(1)?.isNotEmpty == true
          ? errorhandleMatch.group(1)
          : errorhandleMatch.group(2);
    }

    return null;
  }

  static List<String> parseSelectOptions(String html, String selectId) {
    try {
      html = _unwrapAjaxHtml(html);
      final doc = parse(html);
      final select = doc.querySelector('select#$selectId');
      if (select == null) return [];

      return select
          .querySelectorAll('option')
          .map((option) {
            final value = option.attributes['value'];
            if (value != null) return value;
            return option.text.trim();
          })
          .where((v) => v.isNotEmpty || selectId == 'reason')
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int? parseSignedInt(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'[+-]?\s*\d+').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(
      match.group(0)!.replaceAll(' ', '').replaceAll('+', ''),
    );
  }

  static List<String> parseReasonListItems(String html) {
    try {
      html = _unwrapAjaxHtml(html);
      final doc = parse(html);
      return doc
          .querySelectorAll('#reasonselect li')
          .map((element) => element.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 从 Discuz rate 弹窗响应中解析表单选项与错误。
  static RateFormOptions parseRateFormResponse(String body) {
    final html = _unwrapAjaxHtml(body);
    final error = extractMessagetextError(body);
    if (error != null) {
      return RateFormOptions.withDefaults(error: error);
    }

    var scoreOptions = parseSelectOptions(html, 'rate1');
    var reasonPresets = parseSelectOptions(html, 'reason');
    if (reasonPresets.isEmpty) {
      reasonPresets = parseReasonListItems(html);
    }

    String? formHash;
    String? parsedTid;
    String? parsedPid;
    String? referer;
    String? handleKey;
    int? minScore;
    int? maxScore;
    int? totalScore;
    var notifyAuthorDefault = false;
    var notifyAuthorDisabled = false;

    try {
      final doc = parse(html);
      final rateFormInputs = doc.querySelectorAll('#rateform input');
      final hiddenFields = <String, String>{};
      for (final input in rateFormInputs) {
        final value = input.attributes['value'] ?? '';
        final name = input.attributes['name'];
        if (name != null && name.isNotEmpty) hiddenFields[name] = value;
        final id = input.attributes['id'];
        if (id != null && id.isNotEmpty) hiddenFields[id] = value;
      }
      formHash = hiddenFields['formhash'];
      parsedTid = hiddenFields['tid'];
      parsedPid = hiddenFields['pid'];
      referer = hiddenFields['referer'];
      handleKey = hiddenFields['handlekey'];
      if (rateFormInputs.length >= 5) {
        formHash ??= rateFormInputs[0].attributes['value'];
        parsedTid ??= rateFormInputs[1].attributes['value'];
        parsedPid ??= rateFormInputs[2].attributes['value'];
        referer ??= rateFormInputs[3].attributes['value'];
        handleKey ??= rateFormInputs[4].attributes['value'];
      }

      for (final row in doc.querySelectorAll('.dt.mbm tbody tr')) {
        final cells = row.children;
        for (var i = 0; i < cells.length; i++) {
          final rangeMatch = RegExp(
            r'([+-]?\s*\d+)\s*~\s*([+-]?\s*\d+)',
          ).firstMatch(cells[i].text);
          if (rangeMatch == null) continue;
          minScore = parseSignedInt(rangeMatch.group(1));
          maxScore = parseSignedInt(rangeMatch.group(2));
          if (i + 1 < cells.length) {
            totalScore = parseSignedInt(cells[i + 1].text);
          }
        }
      }

      final notifyAuthor = doc.querySelector('#sendreasonpm');
      if (notifyAuthor != null) {
        notifyAuthorDefault = notifyAuthor.attributes.containsKey('checked');
        notifyAuthorDisabled = notifyAuthor.attributes.containsKey('disabled');
      }
    } catch (_) {}

    if (scoreOptions.isEmpty) {
      scoreOptions = RateFormOptions.defaultScoreOptions;
    }
    if (reasonPresets.isEmpty) {
      reasonPresets = RateFormOptions.defaultReasonPresets;
    }

    return RateFormOptions(
      scoreOptions: scoreOptions,
      reasonPresets: reasonPresets,
      formHash: formHash,
      tid: parsedTid,
      pid: parsedPid,
      referer: referer,
      handleKey: handleKey,
      minScore: minScore,
      maxScore: maxScore,
      totalScore: totalScore,
      notifyAuthorDefault: notifyAuthorDefault,
      notifyAuthorDisabled: notifyAuthorDisabled,
    );
  }

  static String? parseRateSubmitResponse(String body) {
    if (body.contains('rate_succeed') ||
        body.contains('评分成功') ||
        (body.contains('window.location.href') &&
            body.contains('viewthread'))) {
      return null;
    }

    final successMatch = RegExp(
      r"succeedhandle_rate\('([^']*)'",
    ).firstMatch(body);
    if (successMatch != null) return null;

    final error = extractMessagetextError(body);
    if (error != null) return error;

    final showMessageMatch = RegExp(
      r"showmessage\('([^']*)'",
    ).firstMatch(body);
    if (showMessageMatch != null) {
      return showMessageMatch.group(1);
    }

    final alertMatch = RegExp(r"alert\('([^']*)'\)").firstMatch(body);
    if (alertMatch != null) return alertMatch.group(1);

    if (body.trim().isEmpty) {
      return '评分请求无响应，请检查是否已登录';
    }

    return '服务器返回未知响应';
  }

  static ReportFormOptions parseReportFormResponse(
    String body, {
    required String tid,
    int page = 1,
  }) {
    final html = _unwrapAjaxHtml(body);
    if (html.trim().isEmpty) {
      return ReportFormOptions.withDefaults(
        error: '举报表单为空，请稍后重试',
        retryable: true,
      );
    }
    if (html.contains('id="loginform') ||
        html.contains("id='loginform") ||
        html.contains('name="login"')) {
      return ReportFormOptions.withDefaults(error: '请先登录');
    }
    final error = extractReportError(html);
    if (error != null) {
      return ReportFormOptions.withDefaults(error: error);
    }

    final fields = <String, String>{};
    for (final input in parse(html).querySelectorAll('input[name]')) {
      final name = input.attributes['name'];
      final value = input.attributes['value'] ?? '';
      if (name != null && name.isNotEmpty && value.isNotEmpty) {
        fields[name] = value;
      }
    }
    if (fields['formhash'] == null || fields['rid'] == null) {
      return ReportFormOptions.withDefaults(
        error: '举报表单无效，请稍后重试',
        retryable: true,
        fields: fields,
      );
    }
    fields['rtype'] ??= 'post';
    fields['tid'] ??= tid;
    fields['referer'] = ApiConfig.forumReportReferer(tid, page);
    return ReportFormOptions(
      reasons: ReportFormOptions.defaultReasons,
      fields: fields,
    );
  }

  static String? extractReportError(String body) {
    final message = extractMessagetextError(body);
    if (message != null) return message;
    final match = RegExp(
      r"(?:errorhandle_[^(]*|showmessage)\('([^']*)'",
    ).firstMatch(body);
    return match?.group(1)?.trim().isEmpty == true ? null : match?.group(1);
  }

  static String? parseReportSubmitResponse(String body) {
    if (body.contains('report_succeed') || body.contains('举报成功')) {
      return null;
    }
    if (RegExp(r'succeedhandle_[^\(]*report', caseSensitive: false)
        .hasMatch(body)) {
      return null;
    }
    final error = extractReportError(body);
    if (error != null) return error;
    if (body.trim().isEmpty) return '举报请求无响应，请检查是否已登录';
    return '服务器返回未知响应';
  }

  // ===========================================================================
  // HTML 工具（纯）
  // ===========================================================================

  static String stripHtml(String text) {
    return decodeHtmlEntities(
      text
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'),
    ).trim();
  }

  static int parseDateString(String s) {
    try {
      final dt = DateTime.parse(s.trim());
      return dt.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  static int extractMaxPage(String html, {required int fallback}) {
    var maxPage = fallback;
    for (final match in RegExp(r'page=(\d+)').allMatches(html)) {
      final pageNum = int.tryParse(match.group(1) ?? '');
      if (pageNum != null && pageNum > maxPage) maxPage = pageNum;
    }
    return maxPage.clamp(1, maxPage);
  }

  static int parseLooseDateString(String s) {
    final normalized = s.trim().replaceAll('/', '-');
    if (normalized.isEmpty) return 0;
    try {
      final parts = normalized.split(RegExp(r'\s+'));
      final dateParts = parts.first.split('-');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        var hour = 0;
        var minute = 0;
        if (parts.length > 1) {
          final timeParts = parts[1].split(':');
          if (timeParts.length >= 2) {
            hour = int.parse(timeParts[0]);
            minute = int.parse(timeParts[1]);
          }
        }
        return DateTime(year, month, day, hour, minute)
                .millisecondsSinceEpoch ~/
            1000;
      }
    } catch (_) {}
    return parseDateString(normalized);
  }

  // ===========================================================================
  // 私信 / 通知
  // ===========================================================================

  static bool isPmSuccessStatus(String status) {
    return status.endsWith('_succeed') ||
        status.endsWith('_success') ||
        status.endsWith('_succeed_mobile');
  }

  static PmSendFormInfo parsePmSendForm(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final formhash = variables?['formhash']?.toString();
    final message = json['Message'];
    final messageval =
        message is Map ? message['messageval']?.toString() : null;
    final messagestr =
        message is Map ? message['messagestr']?.toString() : null;
    final hasError = messageval != null &&
        messageval.isNotEmpty &&
        !isPmSuccessStatus(messageval);
    return PmSendFormInfo(
      formhash: formhash,
      error: hasError
          ? friendlyDiscuzApiError(
              messageval: messageval,
              messagestr: messagestr,
              fallback: '当前无法发送私信',
            )
          : null,
    );
  }

  static PmSendResult parsePmSendResponse(dynamic data) {
    if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('{')) {
        try {
          return parsePmSendResponse(jsonDecode(trimmed));
        } catch (_) {
          return const PmSendResult.uncertain('发送状态未知，请刷新会话确认后再决定是否重试');
        }
      }
      return const PmSendResult.uncertain('发送状态未知，请刷新会话确认后再决定是否重试');
    }
    if (data is! Map) {
      return const PmSendResult.uncertain('发送状态未知，请刷新会话确认后再决定是否重试');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['error'] != null) {
      return PmSendResult.rejected(
        friendlyDiscuzApiError(
          messageval: map['error']?.toString(),
          messagestr: map['error']?.toString(),
          fallback: '私信发送失败',
        ),
      );
    }
    final message = map['Message'];
    final messageval =
        message is Map ? message['messageval']?.toString() : null;
    final messagestr =
        message is Map ? message['messagestr']?.toString() : null;
    if (messageval != null && isPmSuccessStatus(messageval)) {
      final variables = map['Variables'];
      final pmid = variables is Map ? variables['pmid']?.toString() : null;
      if (pmid == null || pmid.trim().isEmpty) {
        return const PmSendResult.uncertain('服务器已返回成功状态，但缺少私信编号，请刷新会话确认');
      }
      return PmSendResult.success(pmid: pmid, message: messagestr);
    }
    if (messageval != null || messagestr != null) {
      return PmSendResult.rejected(
        friendlyDiscuzApiError(
          messageval: messageval,
          messagestr: messagestr,
          fallback: '私信发送失败',
        ),
      );
    }
    return const PmSendResult.uncertain('发送状态未知，请刷新会话确认后再决定是否重试');
  }

  static PmListResult parsePmListJson(
    Map<String, dynamic> json, {
    int page = 1,
  }) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return PmListResult.empty;

    final message = json['Message'] as Map<String, dynamic>?;
    final messageval = message?['messageval']?.toString() ?? '';
    if (messageval.contains('login_before_enter_home') ||
        messageval.contains('to_login')) {
      throw LoginRequiredException();
    }

    final list = variables['list'] as List? ?? [];
    final items = list
        .map((e) => PrivateMessageItem.fromApiJson(e as Map<String, dynamic>))
        .where((item) => item.touid.isNotEmpty)
        .toList();

    final perpage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 20;
    final count = int.tryParse(variables['count']?.toString() ?? '');
    final totalPages = count != null && count > 0 && perpage > 0
        ? (count / perpage).ceil()
        : (items.length >= perpage ? page + 1 : page);

    return PmListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages.clamp(1, totalPages),
    );
  }

  static PmConversationResult parsePmConversationJson(
    Map<String, dynamic> json, {
    required String partnerUid,
    int page = 1,
  }) {
    final message = json['Message'] as Map<String, dynamic>?;
    final messageval = message?['messageval']?.toString() ?? '';
    if (messageval.contains('login_before_enter_home') ||
        messageval.contains('to_login')) {
      throw LoginRequiredException();
    }

    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return PmConversationResult.empty;
    final list = variables['list'];
    if (list is! List) {
      throw const FormatException('私信会话响应缺少 Variables.list');
    }
    final items = list
        .whereType<Map>()
        .map(
          (item) => PrivateMessage.fromApiJson(
            Map<String, dynamic>.from(item),
            partnerUid: partnerUid,
          ),
        )
        .toList();
    final currentPage =
        int.tryParse(variables['page']?.toString() ?? '') ?? page;
    final perPage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 20;
    final count = int.tryParse(variables['count']?.toString() ?? '');
    final totalPages = count != null && count > 0 && perPage > 0
        ? (count / perPage).ceil()
        : (items.length >= perPage ? currentPage + 1 : currentPage);
    return PmConversationResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  static NoticeListResult parseNoticeListJson(
    Map<String, dynamic> json, {
    int page = 1,
  }) {
    final message = json['Message'] as Map<String, dynamic>?;
    final messageval = message?['messageval']?.toString() ?? '';
    if (messageval.contains('login_before_enter_home') ||
        messageval.contains('to_login')) {
      throw LoginRequiredException();
    }

    final variables = json['Variables'] as Map<String, dynamic>?;
    final list = variables?['list'];
    if (variables == null || list is! List) {
      throw const FormatException('提醒响应缺少 Variables.list');
    }
    final items = <NoticeItem>[];
    for (final raw in list.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final noteHtml = item['note']?.toString() ?? '';
      final linkMatch = _findPostLinkRe.firstMatch(noteHtml);
      final tid = linkMatch?.group(1) ?? linkMatch?.group(4) ?? '';
      final pid = linkMatch?.group(2) ?? linkMatch?.group(3);
      final authorUid = item['authorid']?.toString() ?? '';
      final authorName = item['author']?.toString().trim() ?? '';
      final summary = stripHtml(noteHtml);
      items.add(
        NoticeItem(
          id: item['id']?.toString() ?? '',
          authorUid: authorUid,
          authorName: authorName.isNotEmpty ? authorName : '系统通知',
          summary: summary,
          dateline: int.tryParse(item['dateline']?.toString() ?? '') ?? 0,
          tid: tid,
          pid: pid,
          avatarUrl: PrivateMessageItem.avatarUrlForUid(authorUid),
          type: classifyNotice(summary),
          isNew: item['new']?.toString() == '1',
        ),
      );
    }

    final currentPage =
        int.tryParse(variables['page']?.toString() ?? '') ?? page;
    final perPage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 20;
    final count = int.tryParse(variables['count']?.toString() ?? '');
    final totalPages = count != null && count > 0 && perPage > 0
        ? (count / perPage).ceil()
        : (items.length >= perPage ? currentPage + 1 : currentPage);
    return NoticeListResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  static final _pmListItemRe = RegExp(
    r'<li>\s*<span class="mimg">.*?subop=view&(?:amp;)?touid=(\d+).*?'
    r'<img src="([^"]+)".*?'
    r'<span class="mtime">([^<]+)</span>\s*(.*?)\s*</p>\s*'
    r'<p class="mtxt">\s*(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  );

  static PmListResult parsePmListHtml(String html, {int page = 1}) {
    final items = <PrivateMessageItem>[];
    for (final match in _pmListItemRe.allMatches(html)) {
      final touid = match.group(1) ?? '';
      final avatarUrl = match.group(2);
      final timeStr = match.group(3)?.trim() ?? '';
      final titleRaw = stripHtml(match.group(4) ?? '');
      final preview = stripHtml(match.group(5) ?? '');
      final isOutgoing = titleRaw.contains('我对');
      final partnerName = extractPmPartnerName(titleRaw);

      items.add(
        PrivateMessageItem(
          touid: touid,
          partnerName: partnerName.isNotEmpty ? partnerName : '用户$touid',
          preview: preview,
          dateline: parseLooseDateString(timeStr),
          isOutgoing: isOutgoing,
          avatarUrl: avatarUrl,
        ),
      );
    }

    final totalPages = extractMaxPage(html, fallback: page);
    return PmListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  static String extractPmPartnerName(String title) {
    final outgoing = RegExp(r'我对\s+(.+?)\s+说').firstMatch(title);
    if (outgoing != null) {
      return outgoing.group(1)?.trim() ?? '';
    }
    final incoming = RegExp(r'(.+?)\s+对我\s+说').firstMatch(title);
    if (incoming != null) {
      return incoming.group(1)?.trim() ?? '';
    }
    return title.replaceAll(RegExp(r'说:?$'), '').trim();
  }

  static final _noticeItemRe = RegExp(
    r'<li class="cl"\s+notice="(\d+)"[^>]*>.*?'
    r'<span class="mimg"><a href="[^"]*uid=(\d+)[^"]*">([^<]*)</a></span>.*?'
    r'<p class="mtit">.*?<span>([^<]+)</span>.*?'
    r'<p class="mbody"[^>]*>(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  );

  static final _findPostLinkRe = RegExp(
    r'goto=findpost&(?:amp;)?(?:ptid=(\d+)&(?:amp;)?pid=(\d+)|pid=(\d+)&(?:amp;)?ptid=(\d+))',
    caseSensitive: false,
  );

  static NoticeListResult parseNoticeListHtml(String html, {int page = 1}) {
    final items = <NoticeItem>[];
    for (final match in _noticeItemRe.allMatches(html)) {
      final id = match.group(1) ?? '';
      final authorUid = match.group(2) ?? '';
      final avatarRaw = match.group(3)?.trim() ?? '';
      final timeStr = match.group(4)?.trim() ?? '';
      final bodyHtml = match.group(5) ?? '';

      final linkMatch = _findPostLinkRe.firstMatch(bodyHtml);
      final tid = linkMatch?.group(1) ?? linkMatch?.group(4) ?? '';
      final pid = linkMatch?.group(2) ?? linkMatch?.group(3);

      final authorName = extractNoticeAuthorName(bodyHtml);
      final summary = stripHtml(bodyHtml);
      final type = classifyNotice(summary);

      final avatarUrl = avatarRaw.startsWith('http')
          ? avatarRaw
          : PrivateMessageItem.avatarUrlForUid(authorUid);

      items.add(
        NoticeItem(
          id: id,
          authorUid: authorUid,
          authorName: authorName.isNotEmpty ? authorName : '用户$authorUid',
          summary: summary,
          dateline: parseLooseDateString(timeStr),
          tid: tid,
          pid: pid,
          avatarUrl: avatarUrl,
          type: type,
        ),
      );
    }

    final totalPages = extractMaxPage(html, fallback: page);
    return NoticeListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  static String extractNoticeAuthorName(String bodyHtml) {
    final match = RegExp(
      r'<a href="[^"]*uid=\d+[^"]*">([^<]+)</a>',
      caseSensitive: false,
    ).firstMatch(bodyHtml);
    return stripHtml(match?.group(1) ?? '');
  }

  static NoticeType classifyNotice(String summary) {
    if (summary.contains('回复了您的帖子')) return NoticeType.reply;
    if (summary.contains('评分')) return NoticeType.rate;
    return NoticeType.other;
  }

  // ===========================================================================
  // 收藏
  // ===========================================================================

  static List<dynamic> _favoriteJsonList(Map<String, dynamic>? variables) {
    if (variables == null) return [];
    for (final key in ['list', 'data', 'favlist']) {
      final value = variables[key];
      if (value is List && value.isNotEmpty) return value;
    }
    return [];
  }

  static FavoriteItem? _favoriteItemFromJson(Map<String, dynamic> json) {
    final idtype = json['idtype']?.toString() ?? '';
    if (idtype == 'fid' || idtype == 'forum') {
      return FavoriteItem.fromForumJson(json);
    }
    if (idtype == 'tid' || idtype == 'thread' || json.containsKey('tid')) {
      return FavoriteItem.fromThreadJson(json);
    }
    if (json.containsKey('fid') && !json.containsKey('tid')) {
      return FavoriteItem.fromForumJson(json);
    }
    return FavoriteItem.fromThreadJson(json);
  }

  static FavoriteListResult parseFavoriteThreadListJson(
    Map<String, dynamic> json, {
    int page = 1,
  }) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return FavoriteListResult.empty;

    final list = _favoriteJsonList(variables);
    final items = list
        .map((e) => _favoriteItemFromJson(e as Map<String, dynamic>))
        .whereType<FavoriteItem>()
        .where((item) => item.id.isNotEmpty)
        .toList();

    final perpage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 20;
    final count = int.tryParse(variables['count']?.toString() ?? '');
    final totalPages = count != null && count > 0 && perpage > 0
        ? (count / perpage).ceil()
        : (items.length >= perpage ? page + 1 : page);

    return FavoriteListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages.clamp(1, totalPages),
    );
  }

  static FavoriteListResult parseFavoriteForumListJson(
    Map<String, dynamic> json, {
    int page = 1,
  }) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return FavoriteListResult.empty;

    final list = _favoriteJsonList(variables);
    final items = list
        .map((e) => _favoriteItemFromJson(e as Map<String, dynamic>))
        .whereType<FavoriteItem>()
        .where((item) => item.type == FavoriteType.forum && item.id.isNotEmpty)
        .toList();

    final perpage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 20;
    final count = int.tryParse(variables['count']?.toString() ?? '');
    final totalPages = count != null && count > 0 && perpage > 0
        ? (count / perpage).ceil()
        : (items.length >= perpage ? page + 1 : page);

    return FavoriteListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages.clamp(1, totalPages),
    );
  }

  static final _favDeleteLinkRe = RegExp(
    r'op=delete&(?:amp;)?favid=(\d+)',
    caseSensitive: false,
  );

  static FavoriteListResult parseFavoriteListHtml(
    String html, {
    int page = 1,
  }) {
    final hasEntries = html.contains('viewthread') ||
        html.contains('forumdisplay') ||
        html.contains('op=delete&favid=');
    if (html.contains('您还没有添加任何收藏') && !hasEntries) {
      return const FavoriteListResult(items: []);
    }

    final items = <FavoriteItem>[];
    final listRegion = _extractFavoriteListRegion(html);

    final blocks = listRegion.split(RegExp(r'<li\b', caseSensitive: false));
    for (var i = 1; i < blocks.length; i++) {
      final item = _parseFavoriteMobileBlock(blocks[i]);
      if (item != null) items.add(item);
    }

    if (items.isEmpty) {
      for (final match in _favDeleteLinkRe.allMatches(listRegion)) {
        final blockStart = match.start > 400 ? match.start - 400 : 0;
        final block = listRegion.substring(blockStart, match.end + 200);
        final item = _parseFavoriteMobileBlock(block);
        if (item != null) items.add(item);
      }
    }

    final totalPages = _extractFavoriteMaxPage(html, fallback: page);
    return FavoriteListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  static String _extractFavoriteListRegion(String html) {
    for (final pattern in [
      RegExp(
        r'<div class="findbox[^"]*"[^>]*>\s*<ul>(.*?)</ul>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<div class="threadlist_box[^"]*"[^>]*>(.*)',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<div class="threadlist[^"]*"[^>]*>(.*)',
        caseSensitive: false,
        dotAll: true,
      ),
    ]) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1) ?? html;
      }
    }
    return html;
  }

  static String _extractFavoriteTitle(String block) {
    final emMatch = RegExp(
      r'<em[^>]*>(.*?)</em>',
      dotAll: true,
    ).firstMatch(block);
    if (emMatch != null) {
      final title = stripHtml(emMatch.group(1) ?? '');
      if (title.isNotEmpty) return title;
    }

    final linkMatch = RegExp(
      r'<a href="[^"]*(?:viewthread|forumdisplay)[^"]*"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(block);
    if (linkMatch != null) {
      return stripHtml(linkMatch.group(1) ?? '');
    }
    return '';
  }

  static FavoriteItem? _parseFavoriteMobileBlock(String block) {
    final favidMatch = _favDeleteLinkRe.firstMatch(block);
    final favid = favidMatch?.group(1) ?? '';

    final forumMatch = RegExp(
      r'forumdisplay&(?:amp;)?fid=(\d+)',
      caseSensitive: false,
    ).firstMatch(block);

    final threadMatch = RegExp(
      r'viewthread&(?:amp;)?tid=(\d+)',
      caseSensitive: false,
    ).firstMatch(block);

    final title = _extractFavoriteTitle(block);

    final timeMatch = RegExp(
      r'<span class="mtime">(\d{4}-\d{1,2}-\d{1,2})</span>',
    ).firstMatch(block);
    final dateline =
        timeMatch != null ? parseDateString(timeMatch.group(1) ?? '') : 0;

    if (threadMatch != null &&
        (forumMatch == null ||
            block.indexOf('viewthread') < block.indexOf('forumdisplay'))) {
      final tid = threadMatch.group(1) ?? '';
      if (tid.isEmpty) return null;

      String? forumName;
      final forumNameMatch = RegExp(
        r'forumdisplay&(?:amp;)?fid=\d+[^>]*>\s*(?:#)?(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(block);
      if (forumNameMatch != null) {
        forumName = stripHtml(forumNameMatch.group(1) ?? '');
      }

      final eyeMatch = RegExp(
        r'dm-eye-fill"></i>\s*(\d[\d,]*)',
      ).firstMatch(block);
      final views = eyeMatch != null
          ? int.tryParse(eyeMatch.group(1)!.replaceAll(',', ''))
          : null;

      final chatMatch = RegExp(
        r'dm-chat-s-fill"></i>\s*(\d[\d,]*)',
      ).firstMatch(block);
      final replies = chatMatch != null
          ? int.tryParse(chatMatch.group(1)!.replaceAll(',', ''))
          : null;

      return FavoriteItem(
        favid: favid,
        type: FavoriteType.thread,
        id: tid,
        title: title,
        dateline: dateline,
        forumName: forumName,
        views: views,
        replies: replies,
      );
    }

    if (forumMatch != null) {
      final fid = forumMatch.group(1) ?? '';
      if (fid.isEmpty) return null;
      final forumTitle = title.isNotEmpty ? title : '版块 #$fid';
      return FavoriteItem(
        favid: favid,
        type: FavoriteType.forum,
        id: fid,
        title: forumTitle,
        dateline: dateline,
      );
    }

    return null;
  }

  static int _extractFavoriteMaxPage(String html, {required int fallback}) {
    final spanMatch = RegExp(
      r'title="共\s*(\d+)\s*页"',
      caseSensitive: false,
    ).firstMatch(html);
    if (spanMatch != null) {
      final pages = int.tryParse(spanMatch.group(1) ?? '');
      if (pages != null && pages > 0) return pages;
    }
    return extractMaxPage(html, fallback: fallback);
  }

  static FavoriteMutationResult parseFavoriteAddJson(
    Map<String, dynamic> json,
  ) {
    final message = json['Message'] as Map<String, dynamic>?;
    final messageval = message?['messageval']?.toString() ?? '';
    final messagestr = message?['messagestr']?.toString() ?? '';

    if (messageval.contains('to_login') ||
        messageval.contains('login_before_enter_home')) {
      return const FavoriteMutationResult(error: '请先登录');
    }

    if (messageval.contains('succeed') ||
        messagestr.contains('成功') ||
        messageval.contains('favorite_succeed')) {
      final variables = json['Variables'] as Map<String, dynamic>?;
      final favid = variables?['favid']?.toString();
      return FavoriteMutationResult(favid: favid);
    }

    if (messagestr.isNotEmpty) {
      return FavoriteMutationResult(error: friendlyFavoriteError(messagestr));
    }
    if (messageval.isNotEmpty) {
      return FavoriteMutationResult(error: friendlyFavoriteError(messageval));
    }
    return const FavoriteMutationResult(error: '收藏失败');
  }

  static FavoriteMutationResult parseFavoriteMutationResponse(String body) {
    if (body.contains('to_login') ||
        body.contains('login_before_enter_home') ||
        body.contains('id="loginform_')) {
      return const FavoriteMutationResult(error: '请先登录');
    }

    if (body.contains('favorite_delete_succeed') ||
        body.contains('favorite_succeed') ||
        body.contains('删除成功') ||
        body.contains('收藏成功') ||
        RegExp(r"succeedhandle_favorite\('").hasMatch(body)) {
      final favid = extractFavoriteFavid(body);
      return FavoriteMutationResult(favid: favid);
    }

    final errorMatch = RegExp(
      r"errorhandle_favorite\('([^']*)'",
    ).firstMatch(body);
    if (errorMatch != null) {
      return FavoriteMutationResult(
        error: friendlyFavoriteError(errorMatch.group(1) ?? ''),
      );
    }

    final alertMatch = RegExp(r"alert\('([^']*)'\)").firstMatch(body);
    if (alertMatch != null) {
      return FavoriteMutationResult(
        error: friendlyFavoriteError(alertMatch.group(1) ?? ''),
      );
    }

    final messageText = RegExp(
      r'id="messagetext"[^>]*>\s*<p>([^<]+)',
    ).firstMatch(body);
    if (messageText != null) {
      final msg = messageText.group(1)?.trim() ?? '';
      if (msg.contains('成功')) {
        final favid = extractFavoriteFavid(body);
        return FavoriteMutationResult(favid: favid);
      }
      if (msg.isNotEmpty) {
        return FavoriteMutationResult(error: friendlyFavoriteError(msg));
      }
    }

    if (body.contains('favorite_cannot_favorite')) {
      return const FavoriteMutationResult(error: '无法收藏该内容');
    }
    if (body.contains('favorite_duplicate')) {
      return const FavoriteMutationResult(error: '已经收藏过了');
    }

    return const FavoriteMutationResult(error: '操作失败，请稍后重试');
  }

  static String? extractFavoriteFavid(String body) {
    final patterns = [
      RegExp(r"'favid'\s*:\s*'(\d+)'"),
      RegExp(r'"favid"\s*:\s*"(\d+)"'),
      RegExp(r'favid=(\d+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String friendlyFavoriteError(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '操作失败，请稍后重试';
    if (text.startsWith('mobile:')) {
      switch (text) {
        case 'mobile:favorite_cannot_favorite':
          return '无法收藏该内容';
        case 'mobile:favorite_duplicate':
          return '已经收藏过了';
        case 'mobile:to_login':
        case 'mobile:login_before_enter_home':
          return '请先登录';
        default:
          return text.replaceFirst('mobile:', '');
      }
    }
    return text;
  }

  // ===========================================================================
  // 用户空间（主题 / 回复列表）
  // ===========================================================================

  static UserSpaceListResult parseSpaceList(
    Map<String, dynamic> json, {
    required String type,
    int page = 1,
  }) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    if (variables == null) return UserSpaceListResult.empty;

    final list = variables['data'] as List? ?? [];
    final items = list
        .map((t) => UserSpaceItem.fromThreadJson(t as Map<String, dynamic>))
        .toList();
    final perpage = int.tryParse(variables['perpage']?.toString() ?? '') ?? 50;
    final hasMore = items.length >= perpage;
    return UserSpaceListResult(
      items: items,
      totalPages: hasMore ? page + 1 : page,
    );
  }

  static final _threadLinkRe = RegExp(
    r'<a\s+href="(?:forum\.php\?mod=viewthread&)?tid=(\d+)[^"]*"[^>]*class="[^"]*xst[^"]*"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _forumNameRe = RegExp(
    r'<p\s+class="xg1">(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _replyViewRe = RegExp(r'<em>(\d+)</em>/(\d+)');
  static final _datelineRe = RegExp(
    r'class="num"><em>(\d{4}-\d{1,2}-\d{1,2}[^<]*)</em>',
  );
  static final _totalPageRe = RegExp(r'page=(\d+)[^"]*"[^>]*>\s*(\d+)\s*</a>');

  static UserSpaceListResult parseSpaceHtml(
    String html, {
    required String type,
    required int page,
  }) {
    if (type == 'reply') {
      return parseSpaceReplyHtml(html, page: page);
    }
    return parseSpaceThreadHtml(html, page: page);
  }

  static UserSpaceListResult parseSpaceThreadHtml(
    String html, {
    required int page,
  }) {
    final items = <UserSpaceItem>[];

    if (html.contains('<div class="threadlist cl">')) {
      // 手机版模板：分块处理，提取 tid/title/time/forum/views/replies
      final blocks = html.split('<li class="list">');
      for (var i = 1; i < blocks.length; i++) {
        final block = blocks[i];

        final tidMatch = RegExp(
          r'viewthread&(?:amp;)?(?:p)?tid=(\d+)',
        ).firstMatch(block);
        if (tidMatch == null) continue;
        final tid = tidMatch.group(1) ?? '';

        final titleMatch = RegExp(
          r'<em[^>]*>(.*?)</em>',
          dotAll: true,
        ).firstMatch(block);
        final subject =
            titleMatch != null ? stripHtml(titleMatch.group(1) ?? '') : '';

        final timeMatch = RegExp(
          r'<span class="mtime">(\d{4}-\d{1,2}-\d{1,2})</span>',
        ).firstMatch(block);
        final dateline =
            timeMatch != null ? parseDateString(timeMatch.group(1) ?? '') : 0;

        final forumMatch = RegExp(
          r'forumdisplay&(?:amp;)?fid=\d+[^"]*"[^>]*>#?(.*?)</a>',
          dotAll: true,
        ).firstMatch(block);
        final forumName =
            forumMatch != null ? stripHtml(forumMatch.group(1) ?? '') : null;

        final eyeMatch = RegExp(
          r'dm-eye-fill"></i>\s*(\d[\d,]*)',
        ).firstMatch(block);
        final views = eyeMatch != null
            ? int.tryParse(eyeMatch.group(1)!.replaceAll(',', '')) ?? 0
            : 0;

        final chatMatch = RegExp(
          r'dm-chat-s-fill"></i>\s*(\d[\d,]*)',
        ).firstMatch(block);
        final replies = chatMatch != null
            ? int.tryParse(chatMatch.group(1)!.replaceAll(',', '')) ?? 0
            : 0;

        items.add(
          UserSpaceItem(
            tid: tid,
            subject: subject,
            forumName: forumName,
            dateline: dateline,
            replies: replies,
            views: views,
          ),
        );
      }
    } else {
      // 桌面版模板
      for (final match in _threadLinkRe.allMatches(html)) {
        final tid = match.group(1) ?? '';
        final subject = stripHtml(match.group(2) ?? '');
        if (tid.isEmpty) continue;

        String? forumName;
        int replies = 0;
        int views = 0;
        int dateline = 0;

        final afterLink = html.substring(match.end, match.end + 500);
        final forumMatch = _forumNameRe.firstMatch(afterLink);
        if (forumMatch != null) {
          forumName = stripHtml(forumMatch.group(1) ?? '');
        }

        final rvMatch = _replyViewRe.firstMatch(afterLink);
        if (rvMatch != null) {
          replies = int.tryParse(rvMatch.group(1) ?? '') ?? 0;
          views = int.tryParse(rvMatch.group(2) ?? '') ?? 0;
        }

        final dlMatch = _datelineRe.firstMatch(afterLink);
        if (dlMatch != null) {
          dateline = parseDateString(dlMatch.group(1) ?? '');
        }

        items.add(
          UserSpaceItem(
            tid: tid,
            subject: subject,
            forumName: forumName,
            dateline: dateline,
            replies: replies,
            views: views,
          ),
        );
      }
    }

    return UserSpaceListResult(
      items: items,
      totalPages: extractTotalPages(html, page),
    );
  }

  static UserSpaceListResult parseSpaceReplyHtml(
    String html, {
    required int page,
  }) {
    final items = <UserSpaceItem>[];

    if (html.contains('<div class="threadlist cl">')) {
      // 手机版模板
      final blocks = html.split('<li class="list">');
      for (var i = 1; i < blocks.length; i++) {
        final block = blocks[i];

        final titleMatch = RegExp(
          r'<em[^>]*>(.*?)</em>',
          dotAll: true,
        ).firstMatch(block);
        var subject =
            titleMatch != null ? stripHtml(titleMatch.group(1) ?? '') : '';

        // 优先从块内 findpost 链接取 tid（兼容 ptid&pid / pid&ptid；空 pid 为标题行）。
        String? blockTid;
        for (final m in _spaceFindPostAnchorRe.allMatches(block)) {
          final href = _unescapeHtmlAmp(m.group(1) ?? '');
          final parsed = _parseSpaceFindPostHref(href);
          if (parsed == null) continue;
          final (tid, pid) = parsed;
          if (pid == null || pid.isEmpty) {
            blockTid ??= tid;
            if (subject.isEmpty) {
              subject = stripHtml(m.group(2) ?? '');
            }
            continue;
          }
          blockTid ??= tid;
          items.add(
            UserSpaceItem(
              tid: tid,
              subject: subject,
              dateline: 0,
              replyExcerpt: stripHtml(m.group(2) ?? ''),
              pid: pid,
              isReply: true,
            ),
          );
        }

        // 块内无 findpost 时再尝试 viewthread tid（兼容旧结构）。
        if (blockTid == null) {
          final tidMatch = RegExp(
            r'mod=viewthread&(?:amp;)?(?:p)?tid=(\d+)',
          ).firstMatch(block);
          blockTid = tidMatch?.group(1);
        }
        if (blockTid == null) continue;
      }
    } else {
      // 桌面版模板
      String? currentSubject;
      String? currentForum;
      String? currentTid;
      final forumLinkRe = RegExp(
        r'<a href="forum-\d+-\d+-\d+.html" class="xg1"[^>]*>(.*?)</a>',
        dotAll: true,
      );

      for (final match in _spaceFindPostAnchorRe.allMatches(html)) {
        final href = _unescapeHtmlAmp(match.group(1) ?? '');
        final parsed = _parseSpaceFindPostHref(href);
        if (parsed == null) continue;
        final (tid, pid) = parsed;
        final text = stripHtml(match.group(2) ?? '');
        if (tid.isEmpty) continue;

        if (pid == null || pid.isEmpty) {
          currentTid = tid;
          currentSubject = text;
          final end =
              match.end + 300 > html.length ? html.length : match.end + 300;
          final after = html.substring(match.end, end);
          final fm = forumLinkRe.firstMatch(after);
          currentForum = fm != null ? stripHtml(fm.group(1) ?? '') : null;
        } else {
          items.add(
            UserSpaceItem(
              tid: tid,
              subject: currentTid == tid ? (currentSubject ?? '') : '',
              forumName: currentTid == tid ? currentForum : null,
              dateline: 0,
              replyExcerpt: text,
              pid: pid,
              isReply: true,
            ),
          );
        }
      }
    }

    final total = html.contains('class="nxt"') ? page + 1 : page;
    return UserSpaceListResult(items: items, totalPages: total);
  }

  /// 空间回复列表中的 findpost `<a href>`（pid/ptid 顺序不限；pid 可空=标题行）。
  static final _spaceFindPostAnchorRe = RegExp(
    r'<a\s+[^>]*href="([^"]*goto=findpost[^"]*)"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );

  static String _unescapeHtmlAmp(String s) =>
      s.replaceAll('&amp;', '&').replaceAll('&amp;amp;', '&');

  /// 解析空间 findpost href → `(tid, pid?)`；pid 空表示主题标题行。
  static (String tid, String? pid)? _parseSpaceFindPostHref(String href) {
    final m = RegExp(
      r'goto=findpost&(?:amp;)?(?:ptid=(\d+)&(?:amp;)?pid=(\d*)|pid=(\d*)&(?:amp;)?ptid=(\d+))',
      caseSensitive: false,
    ).firstMatch(href);
    if (m == null) return null;
    final tid = m.group(1) ?? m.group(4) ?? '';
    if (tid.isEmpty) return null;
    final pidRaw = m.group(2) ?? m.group(3);
    final pid = (pidRaw == null || pidRaw.isEmpty) ? null : pidRaw;
    return (tid, pid);
  }

  static int extractTotalPages(String html, int currentPage) {
    int totalPages = 1;
    for (final m in _totalPageRe.allMatches(html)) {
      final p = int.tryParse(m.group(2) ?? '') ?? 0;
      if (p > totalPages) totalPages = p;
    }
    // "下一页" 链接存在说明至少还有一页
    if (html.contains('class="nxt"') && totalPages <= currentPage) {
      totalPages = currentPage + 1;
    }
    return totalPages;
  }

  // ===========================================================================
  // 搜索
  // ===========================================================================

  static String resolveSearchPageUrl(String pageHref, int page) {
    final trimmed = pageHref.trim();
    if (trimmed.contains('page=')) {
      final withPage = trimmed.replaceFirst(RegExp(r'page=\d*'), 'page=$page');
      return trimmed.startsWith('http')
          ? withPage
          : '${ApiConfig.baseUrl}/$withPage'.replaceFirst(
              '${ApiConfig.baseUrl}//',
              '${ApiConfig.baseUrl}/',
            );
    }
    final join = trimmed.contains('?') ? '&' : '?';
    final path = trimmed.startsWith('http')
        ? trimmed
        : '${ApiConfig.baseUrl}/$trimmed'.replaceFirst(
            '${ApiConfig.baseUrl}//',
            '${ApiConfig.baseUrl}/',
          );
    return '$path${join}page=$page';
  }

  static String? resolveSearchRedirectUrl(String? location) {
    if (location == null || location.trim().isEmpty) return null;

    final baseUri = Uri.parse('${ApiConfig.baseUrl}/');
    final redirectUri = baseUri.resolve(location.trim());
    if (redirectUri.scheme != baseUri.scheme ||
        redirectUri.host != baseUri.host ||
        redirectUri.port != baseUri.port ||
        !redirectUri.path.startsWith(baseUri.path)) {
      return null;
    }
    return redirectUri.toString();
  }

  /// 解析主题搜索 HTML（Discuz `search.php?mod=forum` 移动模板）。
  static ForumSearchPage parseForumSearchHtml(String html) {
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }

    final messageError = extractMessagetextError(html);
    if (messageError != null && messageError.isNotEmpty) {
      return ForumSearchPage(error: messageError);
    }

    final doc = parse(html);
    var count = 0;
    for (final em in doc.querySelectorAll('em')) {
      final text = em.text.trim();
      final match =
          RegExp(r'找到\s*[“"](.+?)[”"]\s*相关内容\s*(\d+)\s*个').firstMatch(text);
      if (match != null) {
        count = int.tryParse(match.group(2) ?? '') ?? 0;
        break;
      }
    }

    final resultItems = doc.querySelectorAll('li.pbw, li.list');
    if (count == 0 && resultItems.isEmpty) {
      return const ForumSearchPage(count: 0);
    }

    final hits = <ForumSearchHit>[];
    for (final li in resultItems) {
      final hit = parseForumSearchHit(li.outerHtml);
      if (hit != null) hits.add(hit);
    }

    var currentPage = 1;
    var totalPages = 1;
    var pageHref = '';
    final pg = doc.querySelector('div.pg');
    if (pg != null) {
      final strong = pg.querySelector('strong');
      currentPage = int.tryParse(strong?.text.trim() ?? '') ?? 1;
      final spanTitle = pg.querySelector('span[title]');
      final titleText = spanTitle?.attributes['title'] ?? spanTitle?.text ?? '';
      final maxMatch = RegExp(r'(\d+)').firstMatch(titleText);
      if (maxMatch != null) {
        totalPages = int.tryParse(maxMatch.group(1) ?? '') ?? 1;
      }
      final firstLink = pg.querySelector('a[href]');
      final href = firstLink?.attributes['href'] ?? '';
      if (href.isNotEmpty) {
        pageHref = href.replaceFirst(RegExp(r'page=\d+'), 'page=');
      }
      if (totalPages < currentPage) totalPages = currentPage;
    }

    return ForumSearchPage(
      hits: hits,
      count: count > 0 ? count : hits.length,
      currentPage: currentPage,
      totalPages: totalPages,
      pageHref: pageHref,
    );
  }

  static ForumSearchHit? parseForumSearchHit(String block) {
    final tidMatch = RegExp(
      r'thread-(\d+)-|(?:[?&]|&amp;)tid=(\d+)',
      caseSensitive: false,
    ).firstMatch(block);
    final tid = tidMatch?.group(1) ?? tidMatch?.group(2) ?? '';
    if (tid.isEmpty) return null;

    final titleMatch = RegExp(
      r'<h3[^>]*>\s*<a[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(block);
    final mobileTitleMatch = RegExp(
      r'class="[^"]*threadlist_tit[^"]*"[^>]*>.*?<em[^>]*>(.*?)</em>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(block);
    final title = stripHtml(
      mobileTitleMatch?.group(1) ?? titleMatch?.group(1) ?? '',
    );
    if (title.isEmpty) return null;

    final paragraphs = RegExp(
      r'<p[^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(block).map((m) => m.group(1) ?? '').toList();

    var snippet = '';
    var forumName = '';
    var author = '';
    var dateline = '';

    if (paragraphs.isNotEmpty) {
      // 末段通常含版块 / 作者 / 时间；中间段为摘要。
      final metaHtml = paragraphs.last;
      final metaText = stripHtml(metaHtml);
      final parts = metaText
          .split(RegExp(r'\s*-\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) forumName = parts[0];
      if (parts.length >= 2) author = parts[1];
      if (parts.length >= 3) dateline = parts.sublist(2).join(' - ');

      for (var i = 0; i < paragraphs.length - 1; i++) {
        final text = stripHtml(paragraphs[i]);
        if (text.isEmpty) continue;
        if (text.startsWith('本帖最后由')) continue;
        snippet = text;
        break;
      }
    }

    if (author.isEmpty) {
      author = stripHtml(
        RegExp(
              r'class="mmc"[^>]*>(.*?)</a>',
              caseSensitive: false,
              dotAll: true,
            ).firstMatch(block)?.group(1) ??
            '',
      );
    }
    if (dateline.isEmpty) {
      dateline = stripHtml(
        RegExp(
              r'class="mtime"[^>]*>(.*?)</span>',
              caseSensitive: false,
              dotAll: true,
            ).firstMatch(block)?.group(1) ??
            '',
      );
    }
    if (forumName.isEmpty) {
      forumName = stripHtml(
        RegExp(
              r'class="mr"[^>]*>.*?<a[^>]*>(.*?)</a>',
              caseSensitive: false,
              dotAll: true,
            ).firstMatch(block)?.group(1) ??
            '',
      );
    }
    if (snippet.isEmpty) {
      snippet = stripHtml(
        RegExp(
              r'class="[^"]*threadlist_mes[^"]*"[^>]*>(.*?)</div>',
              caseSensitive: false,
              dotAll: true,
            ).firstMatch(block)?.group(1) ??
            '',
      );
    }

    return ForumSearchHit(
      tid: tid,
      title: title,
      snippet: snippet,
      forumName: forumName,
      author: author,
      dateline: dateline,
    );
  }

  /// 解析用户搜索 HTML（Discuz `search.php?mod=user`）。
  static UserSearchPage parseUserSearchHtml(String html) {
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }

    final messageError = extractMessagetextError(html);
    if (messageError != null && messageError.isNotEmpty) {
      return UserSearchPage(error: messageError);
    }

    final doc = parse(html);
    final hits = <UserSearchHit>[];
    for (final li in doc.querySelectorAll('li.bbda.cl, li.bbda')) {
      final hit = parseUserSearchHit(li.outerHtml);
      if (hit != null) hits.add(hit);
    }
    return UserSearchPage(hits: hits);
  }

  static String? extractForcedDesktopUrl(String html) {
    final match = RegExp(
      r'<a[^>]*href="([^"]*forcemobile=1[^"]*)"[^>]*>',
      caseSensitive: false,
    ).firstMatch(html);
    final raw = match?.group(1)?.replaceAll('&amp;', '&').trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.hasAuthority && uri.host != Uri.parse(ApiConfig.baseUrl).host) {
      return null;
    }
    return uri.hasAuthority
        ? uri.toString()
        : Uri.parse(ApiConfig.baseUrl).resolveUri(uri).toString();
  }

  static UserSearchHit? parseUserSearchHit(String block) {
    final uidMatch = RegExp(
      r'space-uid-(\d+)|[?&]uid=(\d+)|uid[=/](\d+)',
      caseSensitive: false,
    ).firstMatch(block);
    final uid =
        uidMatch?.group(1) ?? uidMatch?.group(2) ?? uidMatch?.group(3) ?? '';
    if (uid.isEmpty) return null;

    // 优先取用户名链接文本（跳过头像链接内的空/img）。
    final nameMatches = RegExp(
      r'<a[^>]*href="[^"]*(?:space-uid-|uid=)[^"]*"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(block);
    var name = '';
    for (final match in nameMatches) {
      final text = stripHtml(match.group(1) ?? '');
      if (text.isNotEmpty) {
        name = text;
        break;
      }
    }
    if (name.isEmpty) return null;
    return UserSearchHit(uid: uid, name: name);
  }
}
