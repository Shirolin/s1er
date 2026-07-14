import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/user_space_item.dart';
import '../models/poll.dart';
import '../models/quote_info.dart';
import '../models/reply_submit_result.dart';
import '../models/forum_category.dart';
import '../models/user.dart';
import '../models/private_message_item.dart';
import '../models/private_message.dart';
import '../models/notice_item.dart';
import '../models/favorite_item.dart';
import '../models/message_list_result.dart';
import '../models/rate_form.dart';
import '../models/search_result.dart';
import '../models/app_exceptions.dart';
import '../utils/error_handler.dart';
import '../utils/discuz_message.dart';
import 'formhash_service.dart';
import 'http_client.dart';
import 'talker.dart';

export '../models/app_exceptions.dart'
    show LoginRequiredException, ServerMaintenanceException;

class ApiService {
  ApiService(this._httpClient);
  final S1HttpClient _httpClient;

  /// Dio 未自动解析 JSON 时，response.data 可能是 String
  static Map<String, dynamic> ensureJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
        final msg = extractMaintenanceMessage(data);
        throw ServerMaintenanceException(msg);
      }
      return jsonDecode(data) as Map<String, dynamic>;
    }
    throw FormatException('Unexpected response type: ${data.runtimeType}');
  }

  static String extractMaintenanceMessage(String html) {
    final match = RegExp(
      r'<div\s+id="messagetext"[^>]*>\s*<p>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (raw.isNotEmpty) return raw;
    }
    return '服务器维护中，请稍后再试';
  }

  static String buildApiUrl({
    required String module,
    String version = '4',
    Map<String, dynamic>? params,
  }) {
    final queryParams = {
      'version': version,
      'module': module,
      if (params != null) ...params,
    };
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '${ApiConfig.mobileApiUrl}?$queryString';
  }

  /// 检查 API 响应是否表示需要登录（仅用于必须鉴权的接口）。
  static void checkAuthError(dynamic data) {
    final json = _asJsonMap(data);
    if (json != null && isLoginRequiredResponse(json)) {
      throw LoginRequiredException();
    }
  }

  /// 响应是否表示需要登录。
  ///
  /// 公开浏览接口（forumindex / forumdisplay / viewthread）应先尝试解析
  /// 业务数据；仅当解析结果为空且命中此条件时才视为需要登录。
  static bool isLoginRequiredResponse(Map<String, dynamic> json) {
    final message = json['Message'];
    if (message is Map<String, dynamic> &&
        message['messageval'] == 'to_login') {
      return true;
    }
    if (json['error'] == 'to_login') return true;
    return false;
  }

  static Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static void _throwIfLoginRequiredWithNoData(
    Map<String, dynamic> json,
    bool hasData,
  ) {
    if (!hasData && isLoginRequiredResponse(json)) {
      throw LoginRequiredException();
    }
  }

  static bool _hasThreadDetailData(Map<String, dynamic> json) {
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

  static Map<String, int> parseCommentCount(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final commentCount = variables?['commentcount'];
    if (commentCount is! Map) return {};

    return commentCount.map((key, value) {
      return MapEntry(
        key.toString(),
        int.tryParse(value?.toString() ?? '') ?? 0,
      );
    });
  }

  /// 解析投票帖数据。非投票帖或缺少 `special_poll` 时返回 null。
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

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList();
    return [];
  }

  Future<List<ForumCategory>> getForumList() async {
    final url = buildApiUrl(module: ApiConfig.moduleForumIndex);
    var json = await _fetchJson(url);
    var forums = parseForumList(json);
    if (forums.isEmpty && isLoginRequiredResponse(json)) {
      await _warmGuestSession();
      json = await _fetchJson(url);
      forums = parseForumList(json);
    }
    _throwIfLoginRequiredWithNoData(json, forums.isNotEmpty);
    return forums;
  }

  Future<Map<String, dynamic>> _fetchJson(String url) async {
    final response = await _httpClient.get(url);
    return ensureJson(response.data);
  }

  Future<void> _warmGuestSession() async {
    try {
      final url = buildApiUrl(module: ApiConfig.moduleLogin);
      await _httpClient.get(url);
    } catch (_) {}
  }

  Future<List<Thread>> getThreadList(
    String fid, {
    int page = 1,
    String? typeId,
  }) async {
    final result = await getThreadListRaw(fid, page: page, typeId: typeId);
    return parseThreadList(result);
  }

  static String buildThreadListUrl(
    String fid, {
    int page = 1,
    String? typeId,
  }) {
    final params = <String, String>{
      'fid': fid,
      'page': page.toString(),
      'tpp': '50',
    };
    if (typeId != null && typeId.isNotEmpty) {
      params['filter'] = 'typeid';
      params['typeid'] = typeId;
    }
    return buildApiUrl(
      module: ApiConfig.moduleForumDisplay,
      params: params,
    );
  }

  Future<Map<String, dynamic>> getThreadListRaw(
    String fid, {
    int page = 1,
    String? typeId,
  }) async {
    final url = buildThreadListUrl(fid, page: page, typeId: typeId);
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    _throwIfLoginRequiredWithNoData(json, parseThreadList(json).isNotEmpty);
    return json;
  }

  Future<Map<String, dynamic>> getThreadDetail(
    String tid, {
    int page = 1,
    String? authorId,
  }) async {
    final params = <String, String>{
      'tid': tid,
      'page': page.toString(),
    };
    if (authorId != null && authorId.isNotEmpty) {
      params['authorid'] = authorId;
    }
    final url = buildApiUrl(
      module: ApiConfig.moduleViewThread,
      params: params,
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    _throwIfLoginRequiredWithNoData(json, _hasThreadDetailData(json));
    return json;
  }

  /// API 登录：返回 null 表示成功，否则返回错误信息。
  ///
  /// [questionId] / [answer] 为 Discuz 安全提问（未设置时传 `0` / 空串）。
  Future<String?> login(
    String username,
    String password, {
    int questionId = 0,
    String answer = '',
  }) async {
    try {
      // 1. 发起 GET 请求以获取当前会话的 formhash
      final loginInitUrl = buildApiUrl(module: ApiConfig.moduleLogin);
      final initResponse = await _httpClient.get(loginInitUrl);

      String formhash = '';
      final initData = initResponse.data;
      Map<String, dynamic>? initDataMap;
      if (initData is Map<String, dynamic>) {
        initDataMap = initData;
      } else if (initData is String) {
        try {
          initDataMap = jsonDecode(initData) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (initDataMap != null) {
        final variables = initDataMap['Variables'];
        if (variables is Map<String, dynamic>) {
          formhash = variables['formhash'] ?? '';
        }
      }

      if (formhash.isEmpty) {
        if (initData is String && initData.contains('System Error')) {
          return '初始化登录失败：请求被 Discuz! 系统拦截，请确认 `watch_proxy.ps1` 代理脚本已被关闭并重新启动。';
        }
        return '获取登录表单哈希(formhash)失败，请确认代理服务正常运行。';
      }

      // 2. 发起 POST 登录请求
      final loginSubmitUrl = buildApiUrl(
        module: ApiConfig.moduleLogin,
        params: {
          'action': 'login',
          'loginsubmit': 'yes',
          'infloat': 'yes',
          'formhash': formhash,
        },
      );

      final response = await _httpClient.post(
        loginSubmitUrl,
        data: {
          'formhash': formhash,
          'fastloginfield': 'username',
          'username': username,
          'password': password,
          'questionid': '$questionId',
          'answer': questionId == 0 ? '' : answer,
          'cookietime': '2592000',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data;
      Map<String, dynamic>? dataMap;
      if (data is Map<String, dynamic>) {
        dataMap = data;
      } else if (data is String) {
        try {
          dataMap = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          // Mobile API 偶发返回裸 key（如 mobile:login_invalid）
          return friendlyLoginError(messageval: data);
        }
      }

      if (dataMap != null) {
        final message = dataMap['Message'];
        if (message is Map<String, dynamic>) {
          final messageval = message['messageval']?.toString();
          final messagestr = message['messagestr']?.toString();

          if (messageval == 'login_succeed' ||
              messageval?.contains('succeed') == true) {
            await _httpClient.refreshFormhashAfterAuth();
            return null; // 登录成功
          }
          return friendlyLoginError(
            messageval: messageval,
            messagestr: messagestr,
          );
        }
        // 部分错误体把 messageval 放在顶层
        final topVal =
            dataMap['messageval']?.toString() ?? dataMap['error']?.toString();
        if (topVal != null && topVal.isNotEmpty) {
          return friendlyLoginError(
            messageval: topVal,
            messagestr: dataMap['messagestr']?.toString(),
          );
        }
      }
      return '登录失败，请稍后重试';
    } catch (e) {
      return friendlyError(e, '登录');
    }
  }

  static ReplySubmitResult parseReplyResponse(String xml) {
    final successMatch = RegExp(
      r"succeedhandle_(?:reply|postform)\('([^']*)',\s*'([^']*)',\s*\{([^}]*)\}\)",
    ).firstMatch(xml);
    if (successMatch != null) {
      final meta = successMatch.group(3) ?? '';
      return ReplySubmitResult(
        pid: _extractReplyField(meta, 'pid'),
        tid: _extractReplyField(meta, 'tid'),
      );
    }

    final errorMatch = RegExp(
      r"errorhandle_reply\('([^']*)',\s*'([^']*)'\)",
    ).firstMatch(xml);
    if (errorMatch != null) {
      final message = errorMatch.group(1)?.isNotEmpty == true
          ? errorMatch.group(1)
          : errorMatch.group(2);
      return ReplySubmitResult(error: message);
    }

    final postformError = RegExp(
      r"errorhandle_postform\('([^']*)'",
    ).firstMatch(xml);
    if (postformError != null) {
      return ReplySubmitResult(error: postformError.group(1));
    }

    final alertMatch = RegExp(r"alert\('([^']*)'\)").firstMatch(xml);
    if (alertMatch != null) {
      return ReplySubmitResult(error: alertMatch.group(1));
    }

    final messageText = RegExp(
      r'id="messagetext"[^>]*>\s*<p>([^<]+)',
      dotAll: true,
    ).firstMatch(xml);
    if (messageText != null) {
      return ReplySubmitResult(error: messageText.group(1)?.trim());
    }

    return const ReplySubmitResult(error: '服务器返回未知响应');
  }

  static String? _extractReplyField(String meta, String key) {
    final match = RegExp("'?$key'?\\s*:\\s*'([^']*)'").firstMatch(meta);
    final value = match?.group(1);
    return value != null && value.isNotEmpty ? value : null;
  }

  /// 官方引用助手：拉取 `noticeauthor` / `noticetrimstr`。
  Future<QuoteInfo?> fetchQuoteInfo({
    required String tid,
    required String pid,
  }) async {
    final url = '${ApiConfig.forumPostUrl}'
        '?mod=post&action=reply&inajax=yes'
        '&tid=${Uri.encodeQueryComponent(tid)}'
        '&repquote=${Uri.encodeQueryComponent(pid)}';
    try {
      final response = await _httpClient.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'X-Requested-With': 'XMLHttpRequest'},
        ),
      );
      return QuoteInfo.tryParse(response.data?.toString() ?? '');
    } catch (e, st) {
      talker.handle(e, st, 'fetchQuoteInfo failed');
      return null;
    }
  }

  /// Mobile API 发回复（`module=sendreply`）。
  ///
  /// [message] 仅为用户正文；引用时传入 [quoteInfo]，并由调用方决定
  /// [noticeAuthorMsg]（通常为用户正文缩写，上限 100）。
  Future<ReplySubmitResult> sendReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    String? noticeAuthorMsg,
  }) async {
    final hasFormhash = await _httpClient.ensureFormhash(
      tid: tid,
      fid: fid,
      force: true,
    );
    if (!hasFormhash) {
      return const ReplySubmitResult(
        error: '无法获取表单验证串，请刷新主题页后重试',
      );
    }

    final url = buildApiUrl(
      module: ApiConfig.moduleSendReply,
      params: {'replysubmit': 'yes'},
    );

    final data = <String, String>{
      'tid': tid,
      'message': message,
    };
    if (quoteInfo != null) {
      data['noticeauthor'] = quoteInfo.noticeAuthor;
      data['noticetrimstr'] = quoteInfo.noticeTrimStr;
      final abbr = (noticeAuthorMsg ?? message).trim();
      data['noticeauthormsg'] =
          abbr.length <= 100 ? abbr : '${abbr.substring(0, 100)}…';
    }

    try {
      final response = await _httpClient.post(
        url,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return parseSendReplyResponse(response.data);
    } catch (e, st) {
      return ReplySubmitResult(error: friendlyError(e, '回复', st));
    }
  }

  /// 解析 `module=sendreply` JSON（或偶发裸 key / XML 回落）。
  static ReplySubmitResult parseSendReplyResponse(dynamic data) {
    if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('{')) {
        try {
          return parseSendReplyResponse(jsonDecode(trimmed));
        } catch (_) {
          // fall through to XML legacy / key
        }
      }
      if (trimmed.startsWith('<') ||
          trimmed.contains('succeedhandle_') ||
          trimmed.contains('errorhandle_')) {
        return parseReplyResponse(data);
      }
      if (looksLikeDiscuzMessageKey(trimmed) || trimmed.startsWith('mobile:')) {
        return ReplySubmitResult(
          error: friendlyDiscuzApiError(messageval: trimmed),
        );
      }
      return const ReplySubmitResult(error: '服务器返回异常');
    }

    if (data is! Map) {
      return const ReplySubmitResult(error: '服务器返回异常');
    }
    final map = Map<String, dynamic>.from(data);

    if (map['error'] != null) {
      return ReplySubmitResult(
        error: friendlyDiscuzApiError(
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

    final val = messageval ?? '';
    if (val.contains('succeed')) {
      String? pid;
      String? tid;
      final variables = map['Variables'];
      if (variables is Map) {
        pid = variables['pid']?.toString();
        tid = variables['tid']?.toString();
        if (pid != null && pid.isEmpty) pid = null;
        if (tid != null && tid.isEmpty) tid = null;
      }
      return ReplySubmitResult(pid: pid, tid: tid);
    }

    return ReplySubmitResult(
      error: friendlyDiscuzApiError(
        messageval: messageval,
        messagestr: messagestr,
        fallback: '回复失败，请稍后重试',
      ),
    );
  }

  /// 发回复（旧 Web XML 路径）。请改用 [sendReply]。
  @Deprecated('Use sendReply (module=sendreply) instead')
  Future<ReplySubmitResult> sendPost({
    required String fid,
    required String tid,
    required String message,
    String? reppost,
    String? noticeAuthor,
    String? noticeAuthorMsg,
  }) async {
    final hasFormhash = await _httpClient.ensureFormhash(
      tid: tid,
      fid: fid,
      force: true,
    );
    if (!hasFormhash) {
      return const ReplySubmitResult(
        error: '无法获取表单验证串，请刷新主题页后重试',
      );
    }

    var url = '${ApiConfig.forumPostUrl}'
        '?mod=post&action=reply&fid=$fid&tid=$tid'
        '&extra=&replysubmit=yes&mobile=2&handlekey=postform&inajax=1';
    if (reppost != null && reppost.isNotEmpty) {
      url += '&reppost=$reppost';
    }

    final data = <String, String>{
      'posttime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'usesig': '1',
      'subject': '',
      'message': message,
      'replysubmit': 'yes',
    };
    if (noticeAuthor != null && noticeAuthor.isNotEmpty) {
      data['noticeauthor'] = noticeAuthor;
    }
    if (noticeAuthorMsg != null && noticeAuthorMsg.isNotEmpty) {
      data['noticeauthormsg'] = noticeAuthorMsg;
    }

    final response = await _httpClient.post(
      url,
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final responseData = response.data;
    if (responseData is! String) {
      return const ReplySubmitResult(error: '服务器返回异常');
    }
    return parseReplyResponse(responseData);
  }

  static String _buildPollVoteBody(String tid, List<String> optionIds) {
    final parts = <String>[
      'tid=${Uri.encodeComponent(tid)}',
      'pollsubmit=yes',
    ];
    for (final id in optionIds) {
      parts.add('pollanswers%5B%5D=${Uri.encodeComponent(id)}');
    }
    return parts.join('&');
  }

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

  /// 提交投票。成功返回 null，失败返回错误信息。
  Future<String?> votePoll({
    required String tid,
    required List<String> optionIds,
  }) async {
    if (optionIds.isEmpty) return '请至少选择一个选项';

    final url = '${ApiConfig.forumPostUrl}'
        '?mod=misc&action=votepoll&inajax=1&tid=$tid';

    final response = await _httpClient.post(
      url,
      data: _buildPollVoteBody(tid, optionIds),
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data;
    if (data is! String) return '服务器返回异常';
    return parsePollVoteResponse(data);
  }

  // ── 评分（战斗力）──────────────────────────────────────────

  static String? _extractMessagetextError(String body) {
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

  static List<String> _parseSelectOptions(String html, String selectId) {
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

  static String _unwrapAjaxHtml(String body) {
    final cdataMatch = RegExp(
      r'<!\[CDATA\[(.*)\]\]>',
      dotAll: true,
    ).firstMatch(body);
    return cdataMatch?.group(1) ?? body;
  }

  static int? _parseSignedInt(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'[+-]?\s*\d+').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(
      match.group(0)!.replaceAll(' ', '').replaceAll('+', ''),
    );
  }

  static List<String> _parseReasonListItems(String html) {
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
    final error = _extractMessagetextError(body);
    if (error != null) {
      return RateFormOptions.withDefaults(error: error);
    }

    var scoreOptions = _parseSelectOptions(html, 'rate1');
    var reasonPresets = _parseSelectOptions(html, 'reason');
    if (reasonPresets.isEmpty) {
      reasonPresets = _parseReasonListItems(html);
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
          minScore = _parseSignedInt(rangeMatch.group(1));
          maxScore = _parseSignedInt(rangeMatch.group(2));
          if (i + 1 < cells.length) {
            totalScore = _parseSignedInt(cells[i + 1].text);
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

  /// 预取评分表单（GET）。同时更新 formhash。
  Future<RateFormOptions> fetchRateForm({
    required String tid,
    required String pid,
  }) async {
    await _httpClient.ensureFormhash(tid: tid);

    final url = '${ApiConfig.forumPostUrl}'
        '?mod=misc&action=rate&tid=$tid&pid=$pid&mobile=2&inajax=1';

    try {
      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data?.toString() ?? '';

      final formhash = FormhashExtractor.fromHtml(body);
      if (formhash != null) {
        _httpClient.updateFormhash(formhash);
      }

      return parseRateFormResponse(body);
    } catch (e) {
      if (e is LoginRequiredException) {
        return RateFormOptions.withDefaults(error: '请先登录');
      }
      return RateFormOptions.withDefaults(
        error: friendlyError(e, '获取评分表单'),
        retryable: true,
      );
    }
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

    final error = _extractMessagetextError(body);
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

  /// 提交评分。成功返回 null，失败返回错误信息。
  Future<String?> submitRate({
    required String tid,
    required String pid,
    required String score1,
    String reason = '',
    bool notifyAuthor = false,
    RateFormOptions? form,
  }) async {
    const url = '${ApiConfig.forumPostUrl}'
        '?mod=misc&action=rate&ratesubmit=yes&infloat=yes&inajax=1';

    final data = <String, String>{
      'tid': form?.tid?.isNotEmpty == true ? form!.tid! : tid,
      'pid': form?.pid?.isNotEmpty == true ? form!.pid! : pid,
      'referer': form?.referer?.isNotEmpty == true
          ? form!.referer!
          : ApiConfig.forumRateReferer(tid, pid),
      'handlekey':
          form?.handleKey?.isNotEmpty == true ? form!.handleKey! : 'rate',
      'score1': score1,
      'reason': reason,
      'ratesubmit': 'true',
    };
    if (form?.formHash?.isNotEmpty == true) {
      data['formhash'] = form!.formHash!;
    }
    if (notifyAuthor) {
      data['sendreasonpm'] = '1';
    }

    try {
      final response = await _httpClient.post(
        url,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      final body = response.data?.toString() ?? '';
      return parseRateSubmitResponse(body);
    } catch (e) {
      if (e is LoginRequiredException) return '请先登录';
      return friendlyError(e, '评分');
    }
  }

  Future<User?> getUserProfile() async {
    try {
      final url = buildApiUrl(module: ApiConfig.moduleForumIndex);
      final response = await _httpClient.get(url);
      final json = ensureJson(response.data);
      checkAuthError(json);
      final variables = json['Variables'] as Map<String, dynamic>?;
      if (variables == null) return null;

      final uid = variables['member_uid']?.toString() ?? '';
      if (uid.isEmpty || uid == '0') return null;

      final group = variables['group'] as Map<String, dynamic>?;
      var user = User(
        uid: uid,
        username: variables['member_username']?.toString() ?? '',
        avatar: variables['member_avatar']?.toString(),
        groupTitle: group?['grouptitle']?.toString(),
        credits:
            int.tryParse(variables['member_credits']?.toString() ?? '') ?? 0,
        groupid: int.tryParse(variables['groupid']?.toString() ?? ''),
      );

      try {
        final profileUrl = buildApiUrl(
          module: ApiConfig.moduleProfile,
          params: {'uid': uid},
        );
        final profileResponse = await _httpClient.get(profileUrl);
        final profileJson = ensureJson(profileResponse.data);
        final profileVars = profileJson['Variables'] as Map<String, dynamic>?;
        if (profileVars != null) {
          final space = profileVars['space'] as Map<String, dynamic>?;
          if (space != null) {
            user = user.copyWith(
              posts:
                  int.tryParse(space['posts']?.toString() ?? '') ?? user.posts,
              threads: int.tryParse(space['threads']?.toString() ?? '') ??
                  user.threads,
              friends: int.tryParse(space['friends']?.toString() ?? '') ??
                  user.friends,
              follower: int.tryParse(space['follower']?.toString() ?? '') ?? 0,
              following:
                  int.tryParse(space['following']?.toString() ?? '') ?? 0,
              oltime: int.tryParse(space['oltime']?.toString() ?? '') ?? 0,
              combat: int.tryParse(space['extcredits1']?.toString() ?? '') ?? 0,
              deadfish:
                  int.tryParse(space['extcredits5']?.toString() ?? '') ?? 0,
              regdate: space['regdate']?.toString() ?? '',
            );
          }
        }
      } catch (_) {}

      return user;
    } catch (_) {
      return null;
    }
  }

  // ── 用户空间：主题列表 / 回复列表 ──────────────────────────

  /// 获取当前登录用户的空间列表（通过 mythread 移动端 API）。
  /// [type] 为 'thread' 或 'reply'。
  Future<UserSpaceListResult> getMySpaceList({
    required String type,
    int page = 1,
  }) async {
    final url = buildApiUrl(
      module: 'mythread',
      params: {'type': type, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    checkAuthError(json);
    return _parseSpaceList(json, type: type, page: page);
  }

  /// 获取任意用户的空间列表（通过 HTML 解析）。
  /// 需要已登录才能查看。
  Future<UserSpaceListResult> getUserSpaceList({
    required String uid,
    required String type,
    int page = 1,
  }) async {
    final url = '${ApiConfig.baseUrl}/home.php'
        '?mod=space&uid=$uid&do=thread&view=me&type=$type&from=space&page=$page';
    final response = await _httpClient.get(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data as String;
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }
    return _parseSpaceHtml(html, type: type, page: page);
  }

  static UserSpaceListResult _parseSpaceList(
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

  static UserSpaceListResult _parseSpaceHtml(
    String html, {
    required String type,
    required int page,
  }) {
    if (type == 'reply') {
      return _parseReplyHtml(html, page: page);
    }
    return _parseThreadHtml(html, page: page);
  }

  static UserSpaceListResult _parseThreadHtml(
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
            titleMatch != null ? _stripHtml(titleMatch.group(1) ?? '') : '';

        final timeMatch = RegExp(
          r'<span class="mtime">(\d{4}-\d{1,2}-\d{1,2})</span>',
        ).firstMatch(block);
        final dateline =
            timeMatch != null ? _parseDateString(timeMatch.group(1) ?? '') : 0;

        final forumMatch = RegExp(
          r'forumdisplay&(?:amp;)?fid=\d+[^"]*"[^>]*>#?(.*?)</a>',
          dotAll: true,
        ).firstMatch(block);
        final forumName =
            forumMatch != null ? _stripHtml(forumMatch.group(1) ?? '') : null;

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
        final subject = _stripHtml(match.group(2) ?? '');
        if (tid.isEmpty) continue;

        String? forumName;
        int replies = 0;
        int views = 0;
        int dateline = 0;

        final afterLink = html.substring(match.end, match.end + 500);
        final forumMatch = _forumNameRe.firstMatch(afterLink);
        if (forumMatch != null) {
          forumName = _stripHtml(forumMatch.group(1) ?? '');
        }

        final rvMatch = _replyViewRe.firstMatch(afterLink);
        if (rvMatch != null) {
          replies = int.tryParse(rvMatch.group(1) ?? '') ?? 0;
          views = int.tryParse(rvMatch.group(2) ?? '') ?? 0;
        }

        final dlMatch = _datelineRe.firstMatch(afterLink);
        if (dlMatch != null) {
          dateline = _parseDateString(dlMatch.group(1) ?? '');
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
      totalPages: _extractTotalPages(html, page),
    );
  }

  static UserSpaceListResult _parseReplyHtml(String html, {required int page}) {
    final items = <UserSpaceItem>[];

    if (html.contains('<div class="threadlist cl">')) {
      // 手机版模板
      final blocks = html.split('<li class="list">');
      for (var i = 1; i < blocks.length; i++) {
        final block = blocks[i];

        final tidMatch = RegExp(
          r'mod=viewthread&(?:amp;)?(?:p)?tid=(\d+)|goto=findpost&(?:amp;)?ptid=(\d+)&(?:amp;)?pid=&',
        ).firstMatch(block);
        if (tidMatch == null) continue;
        final tid = tidMatch.group(1) ?? tidMatch.group(2) ?? '';

        final titleMatch = RegExp(
          r'<em[^>]*>(.*?)</em>',
          dotAll: true,
        ).firstMatch(block);
        final subject =
            titleMatch != null ? _stripHtml(titleMatch.group(1) ?? '') : '';

        final replyRe = RegExp(
          r'mod=redirect&(?:amp;)?goto=findpost&(?:amp;)?ptid=\d+&(?:amp;)?pid=(\d+)[^>]*>\s*(?:<div class="quote">)?<blockquote>(.*?)</blockquote>',
          dotAll: true,
        );
        for (final rm in replyRe.allMatches(block)) {
          items.add(
            UserSpaceItem(
              tid: tid,
              subject: subject,
              dateline: 0,
              replyExcerpt: _stripHtml(rm.group(2) ?? ''),
              pid: rm.group(1),
              isReply: true,
            ),
          );
        }
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

      final findpostRe = RegExp(
        r'mod=redirect&(?:amp;)?goto=findpost&(?:amp;)?ptid=(\d+)&(?:amp;)?pid=(\d*)[&"][^>]*>(.*?)</a>',
        dotAll: true,
      );
      for (final match in findpostRe.allMatches(html)) {
        final tid = match.group(1) ?? '';
        final pid = match.group(2) ?? '';
        final text = _stripHtml(match.group(3) ?? '');
        if (tid.isEmpty) continue;

        if (pid.isEmpty) {
          currentTid = tid;
          currentSubject = text;
          final after = html.substring(match.end, match.end + 300);
          final fm = forumLinkRe.firstMatch(after);
          currentForum = fm != null ? _stripHtml(fm.group(1) ?? '') : null;
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

  static int _extractTotalPages(String html, int currentPage) {
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

  static String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static int _parseDateString(String s) {
    try {
      final dt = DateTime.parse(s.trim());
      return dt.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  final Map<String, int> _pageCache = {};

  /// 定位特定回复所在的页码。
  Future<int> locatePostPage(String tid, String pid) async {
    final cacheKey = '$tid:$pid';
    final cached = _pageCache[cacheKey];
    if (cached != null) return cached;

    final url = '${ApiConfig.baseUrl}/forum.php'
        '?mod=redirect&goto=findpost&ptid=$tid&pid=$pid';
    try {
      // 原生平台：只拿 302 header，不下 body
      final response = await _httpClient.get(
        url,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
          responseType: ResponseType.plain,
        ),
      );

      // 优先从 Location header 解析
      final location = response.headers.value('location');
      if (location != null) {
        final uri = Uri.parse(location);
        final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
        _pageCache[cacheKey] = page;
        return page;
      }

      // Web 代理已跟随重定向，从响应 HTML 解析
      final html = response.data as String;
      final pageMatch = RegExp(
        r'<strong[^>]*>(\d+)</strong>|class="cur"[^>]*>(\d+)<',
      ).firstMatch(html);
      if (pageMatch != null) {
        final p = pageMatch.group(1) ?? pageMatch.group(2) ?? '';
        final page = int.tryParse(p) ?? 1;
        _pageCache[cacheKey] = page;
        return page;
      }
    } catch (_) {}
    return 1;
  }

  /// 获取私信会话列表（优先 Mobile API，失败时 HTML 兜底）。
  Future<PmListResult> getPmList({int page = 1}) async {
    try {
      final url = buildApiUrl(
        module: ApiConfig.moduleMyPm,
        params: {'page': page.toString()},
      );
      final response = await _httpClient.get(url);
      final json = ensureJson(response.data);
      checkAuthError(json);
      final result = parsePmListJson(json, page: page);
      if (result.items.isNotEmpty) return result;
    } catch (e) {
      if (e is LoginRequiredException) rethrow;
    }
    return getPmListHtml(page: page);
  }

  /// HTML 兜底：私信会话列表。
  Future<PmListResult> getPmListHtml({int page = 1}) async {
    final url = '${ApiConfig.baseUrl}/home.php'
        '?mod=space&do=pm&filter=privatepm&page=$page';
    final response = await _httpClient.get(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data as String;
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }
    return parsePmListHtml(html, page: page);
  }

  /// 获取与指定用户的私信会话。
  Future<PmConversationResult> getPmConversation(
    String touid, {
    int page = 1,
  }) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleMyPm,
      params: {
        'subop': 'view',
        'touid': touid,
        'page': page.toString(),
      },
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    checkAuthError(json);
    return parsePmConversationJson(json, partnerUid: touid, page: page);
  }

  /// 获取提醒列表（v3 JSON 优先，同分类 HTML 兜底）。
  Future<NoticeListResult> getNoticeList({
    NoticeFeed feed = NoticeFeed.mypost,
    int page = 1,
  }) async {
    try {
      final url = buildApiUrl(
        module: ApiConfig.moduleMyNoteList,
        version: '3',
        params: {
          'view': feed.name,
          'type': 'post',
          'page': page.toString(),
        },
      );
      final response = await _httpClient.get(url);
      final json = ensureJson(response.data);
      checkAuthError(json);
      return parseNoticeListJson(json, page: page);
    } catch (error, stackTrace) {
      if (error is LoginRequiredException) rethrow;
      talker.handle(error, stackTrace, 'mynotelist JSON failed; using HTML');
    }
    return getNoticeListHtml(feed: feed, page: page);
  }

  Future<NoticeListResult> getNoticeListHtml({
    NoticeFeed feed = NoticeFeed.mypost,
    int page = 1,
  }) async {
    final url = '${ApiConfig.baseUrl}/home.php'
        '?mod=space&do=notice&view=${feed.name}&type=&isread=1&page=$page';
    final response = await _httpClient.get(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data as String;
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }
    return parseNoticeListHtml(html, page: page);
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
      final summary = _stripHtml(noteHtml);
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
          type: _classifyNotice(summary),
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
      final titleRaw = _stripHtml(match.group(4) ?? '');
      final preview = _stripHtml(match.group(5) ?? '');
      final isOutgoing = titleRaw.contains('我对');
      final partnerName = _extractPmPartnerName(titleRaw);

      items.add(
        PrivateMessageItem(
          touid: touid,
          partnerName: partnerName.isNotEmpty ? partnerName : '用户$touid',
          preview: preview,
          dateline: _parseLooseDateString(timeStr),
          isOutgoing: isOutgoing,
          avatarUrl: avatarUrl,
        ),
      );
    }

    final totalPages = _extractMaxPage(html, fallback: page);
    return PmListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  static String _extractPmPartnerName(String title) {
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

      final authorName = _extractNoticeAuthorName(bodyHtml);
      final summary = _stripHtml(bodyHtml);
      final type = _classifyNotice(summary);

      final avatarUrl = avatarRaw.startsWith('http')
          ? avatarRaw
          : PrivateMessageItem.avatarUrlForUid(authorUid);

      items.add(
        NoticeItem(
          id: id,
          authorUid: authorUid,
          authorName: authorName.isNotEmpty ? authorName : '用户$authorUid',
          summary: summary,
          dateline: _parseLooseDateString(timeStr),
          tid: tid,
          pid: pid,
          avatarUrl: avatarUrl,
          type: type,
        ),
      );
    }

    final totalPages = _extractMaxPage(html, fallback: page);
    return NoticeListResult(
      items: items,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  static String _extractNoticeAuthorName(String bodyHtml) {
    final match = RegExp(
      r'<a href="[^"]*uid=\d+[^"]*">([^<]+)</a>',
      caseSensitive: false,
    ).firstMatch(bodyHtml);
    return _stripHtml(match?.group(1) ?? '');
  }

  static NoticeType _classifyNotice(String summary) {
    if (summary.contains('回复了您的帖子')) return NoticeType.reply;
    if (summary.contains('评分')) return NoticeType.rate;
    return NoticeType.other;
  }

  // ── 收藏：列表 / 添加 / 删除 ──────────────────────────────

  /// 获取收藏列表。三 Tab 均走 `home.php?do=favorite` HTML；JSON API 作兜底。
  Future<FavoriteListResult> getFavoriteList({
    required String uid,
    String? type,
    int page = 1,
  }) async {
    final htmlResult = await _getFavoriteListHtml(
      uid: uid,
      type: type,
      page: page,
    );
    if (htmlResult.items.isNotEmpty) return htmlResult;

    if (type == 'thread') {
      return _getFavoriteThreadListJson(page: page);
    }
    if (type == 'forum') {
      return _getFavoriteForumListJson(page: page);
    }
    return htmlResult;
  }

  Future<FavoriteListResult> _getFavoriteThreadListJson({int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleMyFavThread,
      params: {'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    checkAuthError(json);
    return parseFavoriteThreadListJson(json, page: page);
  }

  Future<FavoriteListResult> _getFavoriteForumListJson({int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleMyFavForum,
      params: {'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    checkAuthError(json);
    return _parseFavoriteForumListJson(json, page: page);
  }

  Future<FavoriteListResult> _getFavoriteListHtml({
    required String uid,
    String? type,
    int page = 1,
  }) async {
    final typeParam = (type != null && type.isNotEmpty) ? '&type=$type' : '';
    final url = '${ApiConfig.baseUrl}/home.php'
        '?mod=space&uid=$uid&do=favorite&view=me$typeParam&page=$page&mobile=2';
    final response = await _httpClient.get(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data as String;
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }
    return parseFavoriteListHtml(html, page: page);
  }

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

  static FavoriteListResult _parseFavoriteForumListJson(
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
      final title = _stripHtml(emMatch.group(1) ?? '');
      if (title.isNotEmpty) return title;
    }

    final linkMatch = RegExp(
      r'<a href="[^"]*(?:viewthread|forumdisplay)[^"]*"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(block);
    if (linkMatch != null) {
      return _stripHtml(linkMatch.group(1) ?? '');
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
        timeMatch != null ? _parseDateString(timeMatch.group(1) ?? '') : 0;

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
        forumName = _stripHtml(forumNameMatch.group(1) ?? '');
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
    return _extractMaxPage(html, fallback: fallback);
  }

  /// 添加收藏（帖子或版块）。走 `spacecp` 表单 POST，与 S1 手机版一致。
  Future<FavoriteMutationResult> addFavorite({
    required FavoriteType type,
    required String id,
  }) async {
    final hasFormhash = await _httpClient.ensureFormhash(force: true);
    if (!hasFormhash) {
      return const FavoriteMutationResult(error: '无法获取表单验证串，请刷新后重试');
    }

    final typeParam = type == FavoriteType.thread ? 'thread' : 'forum';
    final prefetchUrl = '${ApiConfig.baseUrl}/home.php'
        '?mod=spacecp&ac=favorite&type=$typeParam&id=$id&mobile=2&inajax=1';

    try {
      final prefetch = await _httpClient.get(
        prefetchUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final prefetchFormhash =
          FormhashExtractor.fromHtml(prefetch.data?.toString() ?? '');
      if (prefetchFormhash != null) {
        _httpClient.updateFormhash(prefetchFormhash);
      }
    } catch (_) {
      // 预取失败不阻断提交，沿用已有 formhash。
    }

    final referer = type == FavoriteType.thread
        ? ApiConfig.favoriteThreadReferer(id)
        : ApiConfig.favoriteForumReferer(id);
    final url = '${ApiConfig.baseUrl}/home.php'
        '?mod=spacecp&ac=favorite&type=$typeParam&id=$id'
        '&spaceuid=0&mobile=2&handlekey=favoriteform_$id&inajax=1';

    try {
      final response = await _httpClient.post(
        url,
        data: <String, String>{
          'favoritesubmit': 'true',
          'referer': referer,
          'description': '手机收藏',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      final body = response.data?.toString() ?? '';
      return parseFavoriteMutationResponse(body);
    } catch (e) {
      if (e is LoginRequiredException) {
        return const FavoriteMutationResult(error: '请先登录');
      }
      return FavoriteMutationResult(error: friendlyError(e, '收藏'));
    }
  }

  /// 取消收藏。
  Future<FavoriteMutationResult> removeFavorite({
    required String favid,
  }) async {
    final url = '${ApiConfig.baseUrl}/home.php'
        '?mod=spacecp&ac=favorite&op=delete&favid=$favid'
        '&mobile=2&inajax=1&handlekey=favorite';

    try {
      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data?.toString() ?? '';
      final result = parseFavoriteMutationResponse(body);
      if (result.isSuccess) return result;

      final hasFormhash = await _httpClient.ensureFormhash(force: true);
      if (!hasFormhash) {
        return result.error != null
            ? result
            : const FavoriteMutationResult(error: '无法获取表单验证串，请刷新后重试');
      }

      final postUrl = '$url&deletesubmit=yes';
      final postResponse = await _httpClient.post(
        postUrl,
        data: <String, String>{'deletesubmit': 'yes'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      return parseFavoriteMutationResponse(postResponse.data?.toString() ?? '');
    } catch (e) {
      if (e is LoginRequiredException) {
        return const FavoriteMutationResult(error: '请先登录');
      }
      return FavoriteMutationResult(error: friendlyError(e, '取消收藏'));
    }
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
      return FavoriteMutationResult(error: _friendlyFavoriteError(messagestr));
    }
    if (messageval.isNotEmpty) {
      return FavoriteMutationResult(error: _friendlyFavoriteError(messageval));
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
      final favid = _extractFavoriteFavidFromResponse(body);
      return FavoriteMutationResult(favid: favid);
    }

    final errorMatch = RegExp(
      r"errorhandle_favorite\('([^']*)'",
    ).firstMatch(body);
    if (errorMatch != null) {
      return FavoriteMutationResult(
        error: _friendlyFavoriteError(errorMatch.group(1) ?? ''),
      );
    }

    final alertMatch = RegExp(r"alert\('([^']*)'\)").firstMatch(body);
    if (alertMatch != null) {
      return FavoriteMutationResult(
        error: _friendlyFavoriteError(alertMatch.group(1) ?? ''),
      );
    }

    final messageText = RegExp(
      r'id="messagetext"[^>]*>\s*<p>([^<]+)',
    ).firstMatch(body);
    if (messageText != null) {
      final msg = messageText.group(1)?.trim() ?? '';
      if (msg.contains('成功')) {
        final favid = _extractFavoriteFavidFromResponse(body);
        return FavoriteMutationResult(favid: favid);
      }
      if (msg.isNotEmpty) {
        return FavoriteMutationResult(error: _friendlyFavoriteError(msg));
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

  static String? _extractFavoriteFavidFromResponse(String body) {
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

  static String _friendlyFavoriteError(String raw) {
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

  static int _extractMaxPage(String html, {required int fallback}) {
    var maxPage = fallback;
    for (final match in RegExp(r'page=(\d+)').allMatches(html)) {
      final pageNum = int.tryParse(match.group(1) ?? '');
      if (pageNum != null && pageNum > maxPage) maxPage = pageNum;
    }
    return maxPage.clamp(1, maxPage);
  }

  static int _parseLooseDateString(String s) {
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
    return _parseDateString(normalized);
  }

  Future<User?> getUserProfileByUid(String uid) async {
    try {
      final profileUrl = buildApiUrl(
        module: ApiConfig.moduleProfile,
        params: {'uid': uid},
      );
      final response = await _httpClient.get(profileUrl);
      final json = ensureJson(response.data);
      final variables = json['Variables'] as Map<String, dynamic>?;
      if (variables == null) return null;

      final space = variables['space'] as Map<String, dynamic>?;
      if (space == null) return null;

      return User(
        uid: space['uid']?.toString() ?? uid,
        username: space['username']?.toString() ?? '',
        avatar: space['avatar']?.toString(),
        groupTitle: space['group']?['grouptitle']?.toString(),
        credits: int.tryParse(space['credits']?.toString() ?? '') ?? 0,
        posts: int.tryParse(space['posts']?.toString() ?? '') ?? 0,
        threads: int.tryParse(space['threads']?.toString() ?? '') ?? 0,
        friends: int.tryParse(space['friends']?.toString() ?? '') ?? 0,
        follower: int.tryParse(space['follower']?.toString() ?? '') ?? 0,
        following: int.tryParse(space['following']?.toString() ?? '') ?? 0,
        oltime: int.tryParse(space['oltime']?.toString() ?? '') ?? 0,
        combat: int.tryParse(space['extcredits1']?.toString() ?? '') ?? 0,
        deadfish: int.tryParse(space['extcredits5']?.toString() ?? '') ?? 0,
        regdate: space['regdate']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// 主题搜索（`search.php?mod=forum`）。
  ///
  /// 首页：POST `formhash` + `srchtxt`。翻页：优先 GET [pageHref] 模板。
  Future<ForumSearchPage> searchForum({
    required String query,
    int page = 1,
    String? pageHref,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const ForumSearchPage(error: '请输入搜索关键词');
    }

    try {
      final String body;
      if (page > 1 && pageHref != null && pageHref.isNotEmpty) {
        final url = _resolveSearchPageUrl(pageHref, page);
        final response = await _httpClient.get(
          url,
          options: Options(responseType: ResponseType.plain),
        );
        body = response.data?.toString() ?? '';
      } else {
        final hasFormhash = await _httpClient.ensureFormhash(force: true);
        if (!hasFormhash) {
          return const ForumSearchPage(error: '无法获取表单验证串，请刷新后重试');
        }
        final response = await _httpClient.post(
          ApiConfig.searchForumUrl(),
          data: <String, String>{'srchtxt': trimmed},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain,
          ),
        );
        body = response.data?.toString() ?? '';
      }
      return parseForumSearchHtml(body);
    } on LoginRequiredException {
      rethrow;
    } catch (e, st) {
      return ForumSearchPage(error: friendlyError(e, '搜索主题', st));
    }
  }

  /// 用户搜索（`search.php?mod=user`）。
  Future<UserSearchPage> searchUser({required String query}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const UserSearchPage(error: '请输入搜索关键词');
    }

    try {
      final hasFormhash = await _httpClient.ensureFormhash(force: true);
      if (!hasFormhash) {
        return const UserSearchPage(error: '无法获取表单验证串，请刷新后重试');
      }
      final response = await _httpClient.post(
        ApiConfig.searchUserUrl(),
        data: <String, String>{'srchtxt': trimmed},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      final body = response.data?.toString() ?? '';
      return parseUserSearchHtml(body);
    } on LoginRequiredException {
      rethrow;
    } catch (e, st) {
      return UserSearchPage(error: friendlyError(e, '搜索用户', st));
    }
  }

  static String _resolveSearchPageUrl(String pageHref, int page) {
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

  /// 解析主题搜索 HTML（对齐 S1-Next `ForumSearchWrapper`）。
  static ForumSearchPage parseForumSearchHtml(String html) {
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }

    final messageError = _extractMessagetextError(html);
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

    if (count == 0 && doc.querySelectorAll('li.pbw').isEmpty) {
      return const ForumSearchPage(count: 0);
    }

    final hits = <ForumSearchHit>[];
    for (final li in doc.querySelectorAll('li.pbw')) {
      final hit = _parseForumSearchHit(li.outerHtml);
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

  static ForumSearchHit? _parseForumSearchHit(String block) {
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
    final title =
        titleMatch != null ? _stripHtml(titleMatch.group(1) ?? '') : '';
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
      final metaText = _stripHtml(metaHtml);
      final parts = metaText
          .split(RegExp(r'\s*-\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) forumName = parts[0];
      if (parts.length >= 2) author = parts[1];
      if (parts.length >= 3) dateline = parts.sublist(2).join(' - ');

      for (var i = 0; i < paragraphs.length - 1; i++) {
        final text = _stripHtml(paragraphs[i]);
        if (text.isEmpty) continue;
        if (text.startsWith('本帖最后由')) continue;
        snippet = text;
        break;
      }
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

  /// 解析用户搜索 HTML（对齐 S1-Next `UserSearchWrapper`）。
  static UserSearchPage parseUserSearchHtml(String html) {
    if (html.contains('id="loginform_') || html.contains('name="login"')) {
      throw LoginRequiredException();
    }

    final messageError = _extractMessagetextError(html);
    if (messageError != null && messageError.isNotEmpty) {
      return UserSearchPage(error: messageError);
    }

    final doc = parse(html);
    final hits = <UserSearchHit>[];
    for (final li in doc.querySelectorAll('li.bbda.cl, li.bbda')) {
      final hit = _parseUserSearchHit(li.outerHtml);
      if (hit != null) hits.add(hit);
    }
    return UserSearchPage(hits: hits);
  }

  static UserSearchHit? _parseUserSearchHit(String block) {
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
      final text = _stripHtml(match.group(1) ?? '');
      if (text.isNotEmpty) {
        name = text;
        break;
      }
    }
    if (name.isEmpty) return null;
    return UserSearchHit(uid: uid, name: name);
  }
}

class UserSpaceListResult {
  const UserSpaceListResult({required this.items, this.totalPages = 1});
  static const empty = UserSpaceListResult(items: []);
  final List<UserSpaceItem> items;
  final int totalPages;
}
