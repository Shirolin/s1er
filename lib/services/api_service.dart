import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/forum_category.dart';
import 'http_client.dart';

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
    return parseForumList(response.data);
  }

  Future<List<Thread>> getThreadList(String fid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleForumDisplay,
      params: {'fid': fid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    return parseThreadList(response.data);
  }

  Future<Map<String, dynamic>> getThreadDetail(String tid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleViewThread,
      params: {'tid': tid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    return response.data;
  }

  Future<bool> login(String username, String password) async {
    final url = ApiConfig.loginUrl;
    final response = await _httpClient.post(url, data: {
      'username': username,
      'password': password,
      'formhash': '',
      'questionid': '0',
      'answer': '',
    });
    return response.statusCode == 200;
  }

  Future<bool> sendPost({
    required String fid,
    required String tid,
    required String message,
    required String formhash,
  }) async {
    final url = buildApiUrl(module: ApiConfig.moduleSendPost);
    final response = await _httpClient.post(url, data: {
      'fid': fid,
      'tid': tid,
      'message': message,
      'formhash': formhash,
      'posttime': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return response.statusCode == 200;
  }
}
