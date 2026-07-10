import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/user_space_item.dart';
import '../models/poll.dart';
import '../models/reply_submit_result.dart';
import '../models/forum_category.dart';
import '../models/user.dart';
import '../utils/error_handler.dart';
import 'http_client.dart';

class LoginRequiredException implements Exception {
  @override
  String toString() => '请先登录';
}

class ServerMaintenanceException implements Exception {
  ServerMaintenanceException([this.message = '服务器维护中']);
  final String message;
  @override
  String toString() => message;
}

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
    Map<String, dynamic>? params,
  }) {
    final queryParams = {
      'version': '4',
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
    if (message is Map<String, dynamic> && message['messageval'] == 'to_login') {
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
    return threadList
        .map((t) {
          final thread = Thread.fromJson(t as Map<String, dynamic>);
          if (thread.typeId != null &&
              thread.typeName == null &&
              threadTypes.containsKey(thread.typeId)) {
            return thread.copyWith(typeName: threadTypes[thread.typeId]);
          }
          return thread;
        })
        .toList();
  }

  static List<Post> parsePostList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final postList = variables?['postlist'] as List?;
    if (postList == null) return [];
    return postList
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
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
    final forumList = variables['forumlist'] as List? ?? [];
    final Map<String, ForumCategory> forumMap = {};
    for (final f in forumList) {
      final forum = ForumCategory.fromJson(f as Map<String, dynamic>);
      forumMap[forum.fid] = forum;
    }

    // 2. 从 catlist 构建分类树：每个分类的 forums 是 fid 字符串列表
    final catList = variables['catlist'] as List? ?? [];
    final List<ForumCategory> categories = [];
    for (final cat in catList) {
      final catMap = cat as Map<String, dynamic>;
      final catName = catMap['name']?.toString() ?? '';
      final catFid = catMap['fid']?.toString() ?? '';
      final forumIds = (catMap['forums'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

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

      categories.add(ForumCategory(
        fid: catFid,
        name: catName,
        description: '',
        threads: totalThreads,
        posts: totalPosts,
        todayPosts: totalTodayPosts,
        subforums: subforums,
      ),);
    }

    return categories;
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

  Future<List<Thread>> getThreadList(String fid, {int page = 1}) async {
    final result = await getThreadListRaw(fid, page: page);
    return parseThreadList(result);
  }

  Future<Map<String, dynamic>> getThreadListRaw(String fid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleForumDisplay,
      params: {'fid': fid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    _throwIfLoginRequiredWithNoData(json, parseThreadList(json).isNotEmpty);
    return json;
  }

  Future<Map<String, dynamic>> getThreadDetail(String tid, {
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
  Future<String?> login(String username, String password) async {
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
          'questionid': '0',
          'answer': '',
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
        } catch (_) {}
      }

      if (dataMap != null) {
        final message = dataMap['Message'];
        if (message is Map<String, dynamic>) {
          final messageval = message['messageval'];
          final messagestr = message['messagestr'] as String?;
          
          if (messageval == 'login_succeed' || messageval?.contains('succeed') == true) {
            await _httpClient.refreshFormhashAfterAuth();
            return null; // 登录成功
          } else if (messagestr != null) {
            return messagestr; // 登录失败，返回 Discuz 的错误提示
          }
        }
      }
      return '登录失败，服务器返回未知错误';
    } catch (e) {
      return friendlyError(e, '登录');
    }
  }

  static ReplySubmitResult parseReplyResponse(String xml) {
    final successMatch = RegExp(
      r"succeedhandle_reply\('([^']*)',\s*'([^']*)',\s*\{([^}]*)\}\)",
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
    final match = RegExp("$key:'([^']*)'").firstMatch(meta);
    final value = match?.group(1);
    return value != null && value.isNotEmpty ? value : null;
  }

  /// 发回复。成功时 [ReplySubmitResult.error] 为 null。
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
        (body.contains('window.location.href') && body.contains('viewthread'))) {
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
        credits: int.tryParse(variables['member_credits']?.toString() ?? '') ?? 0,
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
              posts: int.tryParse(space['posts']?.toString() ?? '') ?? user.posts,
              threads: int.tryParse(space['threads']?.toString() ?? '') ?? user.threads,
              friends: int.tryParse(space['friends']?.toString() ?? '') ?? user.friends,
              follower: int.tryParse(space['follower']?.toString() ?? '') ?? 0,
              following: int.tryParse(space['following']?.toString() ?? '') ?? 0,
              oltime: int.tryParse(space['oltime']?.toString() ?? '') ?? 0,
              combat: int.tryParse(space['extcredits1']?.toString() ?? '') ?? 0,
              deadfish: int.tryParse(space['extcredits5']?.toString() ?? '') ?? 0,
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

  static UserSpaceListResult _parseThreadHtml(String html, {required int page}) {
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
        final subject = titleMatch != null
            ? _stripHtml(titleMatch.group(1) ?? '')
            : '';

        final timeMatch = RegExp(
          r'<span class="mtime">(\d{4}-\d{1,2}-\d{1,2})</span>',
        ).firstMatch(block);
        final dateline = timeMatch != null
            ? _parseDateString(timeMatch.group(1) ?? '')
            : 0;

        final forumMatch = RegExp(
          r'forumdisplay&(?:amp;)?fid=\d+[^"]*"[^>]*>#?(.*?)</a>',
          dotAll: true,
        ).firstMatch(block);
        final forumName = forumMatch != null
            ? _stripHtml(forumMatch.group(1) ?? '')
            : null;

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

        items.add(UserSpaceItem(
          tid: tid,
          subject: subject,
          forumName: forumName,
          dateline: dateline,
          replies: replies,
          views: views,
        ),);
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

        items.add(UserSpaceItem(
          tid: tid,
          subject: subject,
          forumName: forumName,
          dateline: dateline,
          replies: replies,
          views: views,
        ),);
      }
    }

    return UserSpaceListResult(items: items, totalPages: _extractTotalPages(html, page));
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
        final subject = titleMatch != null
            ? _stripHtml(titleMatch.group(1) ?? '')
            : '';

        final replyRe = RegExp(
          r'mod=redirect&(?:amp;)?goto=findpost&(?:amp;)?ptid=\d+&(?:amp;)?pid=(\d+)[^>]*>\s*(?:<div class="quote">)?<blockquote>(.*?)</blockquote>',
          dotAll: true,
        );
        for (final rm in replyRe.allMatches(block)) {
          items.add(UserSpaceItem(
            tid: tid,
            subject: subject,
            dateline: 0,
            replyExcerpt: _stripHtml(rm.group(2) ?? ''),
            pid: rm.group(1),
            isReply: true,
          ),);
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
          items.add(UserSpaceItem(
            tid: tid,
            subject: currentTid == tid ? (currentSubject ?? '') : '',
            forumName: currentTid == tid ? currentForum : null,
            dateline: 0,
            replyExcerpt: text,
            pid: pid,
            isReply: true,
          ),);
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
}

class UserSpaceListResult {

  const UserSpaceListResult({required this.items, this.totalPages = 1});
  static const empty = UserSpaceListResult(items: []);
  final List<UserSpaceItem> items;
  final int totalPages;
}

