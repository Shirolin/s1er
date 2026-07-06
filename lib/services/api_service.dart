import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/forum_category.dart';
import 'http_client.dart';

class LoginRequiredException implements Exception {
  @override
  String toString() => '请先登录';
}

class ApiService {
  final S1HttpClient _httpClient;

  ApiService(this._httpClient);

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
      final Message = json['Message'];
      if (Message is Map<String, dynamic> && Message['messageval'] == 'to_login') {
        throw LoginRequiredException();
      }
      final Variables = json['Variables'];
      if (Variables is Map<String, dynamic> && Variables['auth'] == null && json['error'] == 'to_login') {
        throw LoginRequiredException();
      }
    }
  }

  static List<Thread> parseThreadList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final threadList = variables?['forum_threadlist'] as List?;
    if (threadList == null) return [];
    return threadList
        .map((t) => Thread.fromJson(t as Map<String, dynamic>))
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

  static List<ForumCategory> parseForumList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final forumList = variables?['forumlist'] as List?;
    if (forumList == null) return [];
    return forumList
        .map((f) => ForumCategory.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<List<ForumCategory>> getForumList() async {
    final url = buildApiUrl(module: ApiConfig.moduleForumIndex);
    final response = await _httpClient.get(url);
    checkAuthError(response.data);
    return parseForumList(response.data);
  }

  Future<List<Thread>> getThreadList(String fid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleForumDisplay,
      params: {'fid': fid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    checkAuthError(response.data);
    return parseThreadList(response.data);
  }

  Future<Map<String, dynamic>> getThreadDetail(String tid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleViewThread,
      params: {'tid': tid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    checkAuthError(response.data);
    return response.data;
  }

  /// 纯 API 登录：返回 null 表示成功，否则返回错误信息
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
        final Message = dataMap['Message'];
        if (Message is Map<String, dynamic>) {
          final messageval = Message['messageval'];
          final messagestr = Message['messagestr'] as String?;
          
          if (messageval == 'login_succeed' || messageval?.contains('succeed') == true) {
            return null; // 登录成功
          } else if (messagestr != null) {
            return messagestr; // 登录失败，返回 Discuz 的错误提示
          }
        }
      }
      return '登录失败，服务器返回未知错误';
    } catch (e) {
      return '登录失败: $e';
    }
  }

  Future<bool> sendPost({
    required String fid,
    required String tid,
    required String message,
  }) async {
    final url = buildApiUrl(module: ApiConfig.moduleSendPost);
    final response = await _httpClient.post(url, data: {
      'fid': fid,
      'tid': tid,
      'message': message,
      'posttime': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return response.statusCode == 200;
  }
}
