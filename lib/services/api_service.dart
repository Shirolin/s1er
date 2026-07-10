import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/poll.dart';
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

  /// 检查 API 响应是否包含需要登录的错误
  static void checkAuthError(dynamic data) {
    Map<String, dynamic>? json;
    if (data is Map<String, dynamic>) {
      json = data;
    } else if (data is String) {
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (json != null) {
      final message = json['Message'];
      if (message is Map<String, dynamic> && message['messageval'] == 'to_login') {
        throw LoginRequiredException();
      }
      final variables = json['Variables'];
      if (variables is Map<String, dynamic> && variables['auth'] == null && json['error'] == 'to_login') {
        throw LoginRequiredException();
      }
    }
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
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    checkAuthError(json);
    return parseForumList(json);
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
    checkAuthError(json);
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
    checkAuthError(json);
    return json;
  }

  /// 纯 API 登录：返回 null 表示成功，否则返回错误信息（仅 Web 端）
  Future<String?> login(String username, String password) async {
    if (!kIsWeb) {
      throw UnsupportedError('Native login must use WebView');
    }
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

  static String? parseReplyResponse(String xml) {
    final successMatch = RegExp(
      r"succeedhandle_reply\('([^']*)',\s*'([^']*)',\s*\{([^}]*)\}\)",
    ).firstMatch(xml);
    if (successMatch != null) return null;

    final errorMatch = RegExp(
      r"errorhandle_reply\('([^']*)',\s*'([^']*)'\)",
    ).firstMatch(xml);
    if (errorMatch != null) {
      return errorMatch.group(1)?.isNotEmpty == true
          ? errorMatch.group(1)
          : errorMatch.group(2);
    }

    final alertMatch = RegExp(r"alert\('([^']*)'\)").firstMatch(xml);
    if (alertMatch != null) return alertMatch.group(1);

    return '服务器返回未知响应';
  }

  /// 发回复。成功返回 null，失败返回错误信息。
  Future<String?> sendPost({
    required String fid,
    required String tid,
    required String message,
  }) async {
    final url = '${ApiConfig.forumPostUrl}'
        '?mod=post&action=reply&fid=$fid&tid=$tid'
        '&extra=&replysubmit=yes&mobile=2&handlekey=postform&inajax=1';

    final response = await _httpClient.post(
      url,
      data: {
        'posttime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
        'usesig': '1',
        'subject': '',
        'message': message,
        'replysubmit': 'yes',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data;
    if (data is! String) return '服务器返回异常';
    return parseReplyResponse(data);
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
              deadfish: int.tryParse(space['extcredits1']?.toString() ?? '') ?? 0,
              combat: int.tryParse(space['extcredits5']?.toString() ?? '') ?? 0,
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
        deadfish: int.tryParse(space['extcredits1']?.toString() ?? '') ?? 0,
        combat: int.tryParse(space['extcredits5']?.toString() ?? '') ?? 0,
        regdate: space['regdate']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
