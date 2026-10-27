import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/user_space_item.dart';
import '../models/quote_info.dart';
import '../models/reply_submit_result.dart';
import '../models/new_thread_form_info.dart';
import '../models/new_thread_submit_result.dart';
import '../models/edit_post_form_info.dart';
import '../models/edit_post_submit_result.dart';
import '../models/forum_category.dart';
import '../models/user.dart';
import '../models/private_message.dart';
import '../models/notice_item.dart';
import '../models/favorite_item.dart';
import '../models/message_list_result.dart';
import '../models/pm_send_result.dart';
import '../models/rate_form.dart';
import '../models/report_form.dart';
import '../models/forum_search_query.dart';
import '../models/thread_list_query.dart';
import '../models/search_result.dart';
import '../models/app_exceptions.dart';
import '../utils/error_handler.dart';
import '../utils/discuz_message.dart';
import '../utils/discuz_submit_response.dart';
import '../utils/forum_attachment_submit.dart';
import '../utils/forum_attachment_upload_info_parser.dart';
import '../utils/new_thread_form_parser.dart';
import '../utils/read_perm_options.dart';
import '../utils/server_notice.dart';
import '../models/forum_attachment_upload_info.dart';
import 'formhash_service.dart';
import 'discuz_parser.dart';
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
        // 1) Discuz 提示页：把服务器原文搬运给用户。
        final official = ServerNotice.fromResponseBody(data);
        if (official != null) throw ServerMaintenanceException(official);
        // 2) JSON 被包在 HTML 里：救援后按正常 JSON 继续
        //    （对应 S1-Orange 的 ensureJSON 场景）。
        final rescued = DiscuzParser.rescueJsonFromHtml(data);
        if (rescued != null) return rescued;
        // 3) 两者都没有：维持既有兜底陈述。
        throw ServerMaintenanceException(extractMaintenanceMessage(data));
      }
      return jsonDecode(data) as Map<String, dynamic>;
    }
    throw FormatException('Unexpected response type: ${data.runtimeType}');
  }

  static String extractMaintenanceMessage(String html) {
    return ServerNotice.fromResponseBody(html) ?? '服务器维护中，请稍后再试';
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

  static void _throwIfNoDataBlocked(
    Map<String, dynamic> json,
    bool hasData,
  ) {
    if (hasData) return;
    if (isLoginRequiredResponse(json)) {
      throw LoginRequiredException();
    }
    final apiError = DiscuzParser.extractApiErrorMessage(json);
    if (apiError != null) {
      throw ServerMaintenanceException(apiError);
    }
  }

  /// 只读预检新主题权限，并缓存响应中的 formhash。
  ///
  /// 主题分类优先从网页发帖助手 (`forum.php?mod=post&action=newthread`) 解析，
  /// 与 S1-Next 对齐；Mobile API 的 `threadtypes` 仅作回退。
  Future<NewThreadFormInfo> fetchNewThreadForm({required String fid}) async {
    try {
      final response = await _httpClient.get(
        buildApiUrl(module: ApiConfig.moduleNewThread, params: {'fid': fid}),
      );
      _httpClient.cacheFormhashFromResponse(response.data);
      final json = ensureJson(response.data);
      final apiResult = DiscuzParser.parseNewThreadForm(json);
      if (apiResult.error != null) return apiResult;

      var threadTypes = apiResult.threadTypes;
      var typeRequired = apiResult.typeRequired;
      try {
        final webResponse = await _httpClient.get(
          ApiConfig.newThreadEditorUrl(fid: fid),
          options: Options(
            responseType: ResponseType.plain,
            extra: const {'s1DesktopUa': true},
          ),
        );
        final webForm = parseNewThreadFormHtml(
          webResponse.data?.toString() ?? '',
        );
        if (webForm.threadTypes.isNotEmpty) {
          threadTypes = webForm.threadTypes;
        }
        if (webForm.typeRequired != null) {
          typeRequired = webForm.typeRequired!;
        }
      } catch (e, st) {
        talker.handle(e, st, 'fetchNewThreadForm web types fallback');
      }

      if (apiResult.formhash == null || apiResult.formhash!.isEmpty) {
        return NewThreadFormInfo(
          threadTypes: threadTypes,
          typeRequired: typeRequired,
          error: '无法获取发帖表单验证串，请稍后重试',
        );
      }
      if (typeRequired && threadTypes.isEmpty) {
        return NewThreadFormInfo(
          formhash: apiResult.formhash,
          typeRequired: true,
          error: '服务器未返回必需的主题分类，请稍后重试',
        );
      }
      return NewThreadFormInfo(
        threadTypes: threadTypes,
        typeRequired: typeRequired,
        formhash: apiResult.formhash,
      );
    } catch (e, st) {
      return NewThreadFormInfo(error: friendlyError(e, '加载发帖表单', st));
    }
  }

  /// 提交一个新主题。提交前必须再次通过只读权限预检。
  ///
  /// 正文含 `[attachimg]` 时改走网页发帖并附带 `attachnew`。
  Future<NewThreadSubmitResult> submitNewThread({
    required String fid,
    required String subject,
    required String message,
    String? typeId,
  }) async {
    final form = await fetchNewThreadForm(fid: fid);
    if (!form.canSubmit) {
      return NewThreadSubmitResult(error: form.error ?? '当前版块暂不可发帖');
    }
    if (form.typeRequired && (typeId == null || typeId.trim().isEmpty)) {
      return const NewThreadSubmitResult(error: '请选择主题分类');
    }

    final normalized = normalizeForumAttachmentMessage(message);
    final aids = collectForumAttachmentIds(normalized);
    if (aids.isNotEmpty) {
      return _submitNewThreadViaWeb(
        fid: fid,
        subject: subject,
        message: normalized,
        typeId: typeId,
        formhash: form.formhash!,
        attachmentIds: aids,
      );
    }

    final url = buildApiUrl(
      module: ApiConfig.moduleNewThread,
      params: {'fid': fid, 'extra': '', 'topicsubmit': 'yes'},
    );
    final data = <String, String>{
      'formhash': form.formhash!,
      'posttime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      if (typeId != null && typeId.trim().isNotEmpty) 'typeid': typeId.trim(),
      'subject': subject.trim(),
      'message': normalized.trim(),
      'allownoticeauthor': '1',
      'usesig': '1',
    };
    try {
      final response = await _httpClient.post(
        url,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return DiscuzParser.parseNewThreadSubmitResponse(response.data);
    } catch (e, st) {
      return NewThreadSubmitResult(error: friendlyError(e, '发帖', st));
    }
  }

  Future<NewThreadSubmitResult> _submitNewThreadViaWeb({
    required String fid,
    required String subject,
    required String message,
    String? typeId,
    required String formhash,
    required Set<String> attachmentIds,
  }) async {
    final data = <String, String>{
      'formhash': formhash,
      'posttime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      if (typeId != null && typeId.trim().isNotEmpty) 'typeid': typeId.trim(),
      'subject': subject.trim(),
      'message': message.trim(),
      'allownoticeauthor': '1',
      'usesig': '1',
      'topicsubmit': 'yes',
    };
    appendAttachNewFields(data, attachmentIds);
    try {
      final response = await _httpClient.post(
        ApiConfig.webNewThreadSubmitUrl(fid: fid),
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          headers: {
            'Referer': ApiConfig.forumAttachmentReferer(fid: fid),
          },
        ),
      );
      final body = DiscuzSubmitResponse.coerceBody(response.data);
      final web = DiscuzParser.parseWebNewThreadSubmitResponse(body);
      if (web != null) return web;
      return DiscuzParser.parseNewThreadSubmitResponse(response.data);
    } catch (e, st) {
      return NewThreadSubmitResult(error: friendlyError(e, '发帖', st));
    }
  }

  /// 只读获取 Discuz Web 编辑页；不触发任何写入。
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.editPostFormUrl(fid: fid, tid: tid, pid: pid),
        options: Options(
          responseType: ResponseType.plain,
          extra: const {'s1DesktopUa': true},
        ),
      );
      final body = response.data?.toString() ?? '';
      return DiscuzParser.parseEditPostFormResponse(body, isFirst: isFirst);
    } catch (e, st) {
      return EditPostFormInfo(error: friendlyError(e, '获取编辑表单', st));
    }
  }

  /// 提交编辑前重新读取表单，避免覆盖服务器已经发生的修改。
  Future<EditPostSubmitResult> submitEditPost({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
    required String subject,
    required String message,
    String? typeId,
    String? readPerm,
    required EditPostFormInfo baseline,
  }) async {
    final normalizedReadPerm = normalizeSelectedReadPerm(readPerm);
    final latest = await fetchEditPostForm(
      fid: fid,
      tid: tid,
      pid: pid,
      isFirst: isFirst,
    );
    if (!latest.canEdit) {
      return EditPostSubmitResult.rejected(latest.error ?? '当前帖子不可编辑');
    }
    if (latest.subject != baseline.subject ||
        latest.message != baseline.message ||
        latest.selectedTypeId != baseline.selectedTypeId ||
        latest.selectedReadPermission != baseline.selectedReadPermission) {
      return const EditPostSubmitResult.conflict(
        '服务器内容已发生变化，请重新载入后再编辑',
      );
    }

    final data = <String, String>{
      'fid': fid,
      'tid': tid,
      'pid': pid,
      'formhash': latest.formhash!,
      'posttime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'subject': isFirst ? subject.trim() : latest.subject,
      'message': normalizeForumAttachmentMessage(message).trim(),
      'allownoticeauthor': '1',
      'usesig': '1',
    };
    if (typeId != null && typeId.trim().isNotEmpty) data['typeid'] = typeId;
    if (normalizedReadPerm != null && normalizedReadPerm.isNotEmpty) {
      data['readperm'] = normalizedReadPerm;
    }
    appendAttachNewFields(
      data,
      collectForumAttachmentIds(data['message']),
    );
    final submittedSubject = data['subject']!;
    final submittedMessage = data['message']!;
    try {
      final response = await _httpClient.post(
        ApiConfig.editPostSubmitUrl(),
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          extra: const {'s1DesktopUa': true},
        ),
      );
      final body = DiscuzSubmitResponse.coerceBody(response.data);
      final parsed = DiscuzParser.parseEditPostSubmitResponse(body);
      if (!parsed.isUncertain) return parsed;
      talker.warning(
        'edit submit parse uncertain; '
        'dataType=${response.data.runtimeType} '
        'status=${response.statusCode} len=${body.length}',
      );
      final verified = await _verifyEditPostApplied(
        fid: fid,
        tid: tid,
        pid: pid,
        isFirst: isFirst,
        subject: submittedSubject,
        message: submittedMessage,
        typeId: typeId,
        readPerm: normalizedReadPerm,
      );
      if (verified) {
        return const EditPostSubmitResult.success(message: '编辑成功');
      }
      return parsed;
    } catch (e, st) {
      talker.handle(e, st, 'submitEditPost transport uncertain');
      final verified = await _verifyEditPostApplied(
        fid: fid,
        tid: tid,
        pid: pid,
        isFirst: isFirst,
        subject: submittedSubject,
        message: submittedMessage,
        typeId: typeId,
        readPerm: normalizedReadPerm,
      );
      if (verified) {
        return const EditPostSubmitResult.success(message: '编辑成功');
      }
      return const EditPostSubmitResult.uncertain(
        '编辑请求状态不确定，请先核对服务器内容，不要直接重复提交',
      );
    }
  }

  /// POST 响应偶发无法解析（类型非 String、超时后仍已写入等）时，回读编辑表单核对正文。
  Future<bool> _verifyEditPostApplied({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
    required String subject,
    required String message,
    String? typeId,
    String? readPerm,
  }) async {
    try {
      final latest = await fetchEditPostForm(
        fid: fid,
        tid: tid,
        pid: pid,
        isFirst: isFirst,
      );
      if (!latest.canEdit) return false;
      if (latest.message.trim() != message.trim()) return false;
      if (isFirst && latest.subject.trim() != subject.trim()) return false;
      if (typeId != null &&
          typeId.trim().isNotEmpty &&
          latest.selectedTypeId != typeId) {
        return false;
      }
      if (readPerm != null && readPerm.isNotEmpty) {
        final latestReadPerm =
            normalizeReadPermValue(latest.selectedReadPermission ?? '');
        if (latestReadPerm != readPerm) {
          return false;
        }
      }
      return true;
    } catch (e, st) {
      talker.handle(e, st, 'verifyEditPostApplied failed');
      return false;
    }
  }

  /// 楼层较多时在后台 isolate 解析，避免阻塞首帧。
  static Future<List<Post>> parsePostListAsync(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final postList = variables?['postlist'] as List?;
    if (postList == null || postList.isEmpty) {
      return Future.value(const []);
    }
    if (postList.length < 12) {
      return Future.value(DiscuzParser.parsePostList(json));
    }
    return compute(DiscuzParser.parsePostList, json);
  }

  Future<List<ForumCategory>> getForumList() async {
    final url = buildApiUrl(module: ApiConfig.moduleForumIndex);
    var json = await _fetchJson(url);
    var forums = DiscuzParser.parseForumList(json);
    if (forums.isEmpty && isLoginRequiredResponse(json)) {
      await _warmGuestSession();
      json = await _fetchJson(url);
      forums = DiscuzParser.parseForumList(json);
    }
    _throwIfNoDataBlocked(json, forums.isNotEmpty);
    if (forums.isEmpty) {
      // 服务器明确说明了「为什么没有数据」→ 原文转达，不自行拟制。
      final reason = DiscuzParser.extractDiscuzMessageError(json);
      if (reason != null) throw ServerMaintenanceException(reason);
    }
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
    ThreadListQuery query = ThreadListQuery.defaults,
  }) async {
    final result = await getThreadListRaw(
      fid,
      page: page,
      typeId: typeId,
      query: query,
    );
    return DiscuzParser.parseThreadList(result);
  }

  static String buildThreadListUrl(
    String fid, {
    int page = 1,
    String? typeId,
    ThreadListQuery query = ThreadListQuery.defaults,
  }) {
    final params = <String, String>{
      'fid': fid,
      'page': page.toString(),
      'tpp': '50',
      ...query.toForumDisplayParams(typeId: typeId),
    };
    return buildApiUrl(
      module: ApiConfig.moduleForumDisplay,
      params: params,
    );
  }

  Future<Map<String, dynamic>> getThreadListRaw(
    String fid, {
    int page = 1,
    String? typeId,
    ThreadListQuery query = ThreadListQuery.defaults,
  }) async {
    final url = buildThreadListUrl(
      fid,
      page: page,
      typeId: typeId,
      query: query,
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    _throwIfNoDataBlocked(json, DiscuzParser.parseThreadList(json).isNotEmpty);
    return json;
  }

  Future<Map<String, dynamic>> getThreadDetail(
    String tid, {
    int page = 1,
    String? authorId,
  }) async {
    try {
      return await _requestThreadDetail(tid, page: page, authorId: authorId);
    } on DioException catch (e) {
      // 论坛升级后部分页面在 version=4 下稳定返回 Discuz System Error (503)，
      // 同一页换成 version=1 正常。只对 503 降一级重试；超时、断网等
      // 传输层错误不重试，避免把瞬时故障放大成重复请求。
      if (e.response?.statusCode != 503) rethrow;
      talker.warning(
        'viewthread v4 returned 503, retrying with version=1 '
        'tid=$tid page=$page',
      );
      return _requestThreadDetail(
        tid,
        page: page,
        authorId: authorId,
        version: legacyApiVersion,
      );
    }
  }

  /// v4 不可用时的降级协议版本（鹅球看帖使用同一版本，长期可用）。
  static const String legacyApiVersion = '1';

  Future<Map<String, dynamic>> _requestThreadDetail(
    String tid, {
    required int page,
    String? authorId,
    String version = '4',
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
      version: version,
      params: params,
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    _throwIfNoDataBlocked(json, DiscuzParser.hasThreadDetailData(json));
    return json;
  }

  /// 按 tid 拉取第 1 页并只返回回复数（完整 viewthread，客户端只解析 replies）。
  Future<int?> fetchThreadReplies(String tid) async {
    final result = await getThreadDetail(tid, page: 1);
    return DiscuzParser.parseThreadReplies(result);
  }

  /// 取本页「有评分」的楼层 pid（v4 `Variables.commentcount` 的键）。
  ///
  /// 正常翻页时直接复用 `viewthread` v4 响应即可；只有 v4 503 降级到 v1 时
  /// 才需要补发这一次请求。失败（含仍 503）返回空集，评分属增强功能，
  /// 不因此中断读帖。
  Future<Set<String>> fetchRateMarkedPids(String tid, {int page = 1}) async {
    try {
      final response = await _httpClient.get(
        buildApiUrl(
          module: ApiConfig.moduleViewThread,
          params: {'tid': tid, 'page': page.toString()},
        ),
      );
      return DiscuzParser.parseRateMarkedPids(ensureJson(response.data));
    } catch (e, st) {
      talker.handle(e, st, 'fetchRateMarkedPids failed tid=$tid page=$page');
      return const {};
    }
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

  /// 预取论坛附件上传凭据（回复 / 发新帖 / 编辑页 HTML）。
  ///
  /// 对齐 S1-Next：编辑走 `action=edit`；回复走 `action=reply&inajax=yes`。
  Future<ForumAttachmentUploadInfo?> fetchForumAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
  }) async {
    final String url;
    if (editPid != null &&
        editPid.isNotEmpty &&
        tid != null &&
        tid.isNotEmpty) {
      url = '${ApiConfig.editPostFormUrl(fid: fid, tid: tid, pid: editPid)}'
          '&inajax=yes&mobile=no';
    } else if (tid != null && tid.isNotEmpty) {
      url = ApiConfig.replyEditorUrl(tid: tid, fid: fid);
    } else {
      url = ApiConfig.newThreadEditorUrl(fid: fid);
    }
    try {
      final response = await _httpClient.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'X-Requested-With': 'XMLHttpRequest'},
          extra: const {'s1DesktopUa': true},
        ),
      );
      return parseForumAttachmentUploadInfo(
        response.data?.toString() ?? '',
        fallbackFid: fid,
      );
    } catch (e, st) {
      talker.handle(e, st, 'fetchForumAttachmentUploadInfo failed');
      return null;
    }
  }

  /// Mobile API 发回复（`module=sendreply`）。
  ///
  /// [message] 仅为用户正文；引用时传入 [quoteInfo]，并由调用方决定
  /// [noticeAuthorMsg]（通常为用户正文缩写，上限 100）。
  ///
  /// 正文含 `[attachimg]` 时改走网页回复并附带 `attachnew`。
  Future<ReplySubmitResult> sendReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    String? noticeAuthorMsg,
  }) async {
    final normalized = normalizeForumAttachmentMessage(message);
    final aids = collectForumAttachmentIds(normalized);
    if (aids.isNotEmpty) {
      return _sendReplyViaWeb(
        tid: tid,
        fid: fid,
        message: normalized,
        quoteInfo: quoteInfo,
        noticeAuthorMsg: noticeAuthorMsg,
        attachmentIds: aids,
      );
    }

    final hasFormhash = await _httpClient.ensureFormhash(
      tid: tid,
      fid: fid,
      force: true,
    );
    if (!hasFormhash) {
      return const ReplySubmitResult.rejected(
        '无法获取表单验证串，请刷新主题页后重试',
      );
    }

    final url = buildApiUrl(
      module: ApiConfig.moduleSendReply,
      params: {'replysubmit': 'yes'},
    );

    final data = <String, String>{
      'tid': tid,
      'message': normalized,
    };
    if (quoteInfo != null) {
      data['noticeauthor'] = quoteInfo.noticeAuthor;
      data['noticetrimstr'] = quoteInfo.submitNoticeTrimStr;
      final abbr = (noticeAuthorMsg ?? message).trim();
      data['noticeauthormsg'] =
          abbr.length <= 100 ? abbr : '${abbr.substring(0, 100)}…';
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
      return DiscuzParser.parseSendReplyResponse(response.data);
    } catch (e, st) {
      if (isTransportUncertainError(e)) {
        talker.handle(e, st, 'sendReply transport uncertain');
        return const ReplySubmitResult.uncertain(
          '回复请求状态不确定，请返回主题刷新确认后再决定是否重发',
        );
      }
      return ReplySubmitResult.rejected(friendlyError(e, '回复', st));
    }
  }

  Future<ReplySubmitResult> _sendReplyViaWeb({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    String? noticeAuthorMsg,
    required Set<String> attachmentIds,
  }) async {
    // 附件回复与上传共用编辑页 formhash；勿 force 清掉再换 Mobile API 串。
    // 仅在缓存为空时拉取（上传预取通常已写入）。
    final hasFormhash = await _httpClient.ensureFormhash(
      tid: tid,
      fid: fid,
    );
    if (!hasFormhash) {
      return const ReplySubmitResult.rejected(
        '无法获取表单验证串，请刷新主题页后重试',
      );
    }

    final data = <String, String>{
      'formhash': _httpClient.currentFormhash,
      'posttime': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'usesig': '1',
      'subject': '',
      'message': message,
      'replysubmit': 'yes',
    };
    if (quoteInfo != null) {
      data['noticeauthor'] = quoteInfo.noticeAuthor;
      data['noticetrimstr'] = quoteInfo.submitNoticeTrimStr;
      final abbr = (noticeAuthorMsg ?? message).trim();
      data['noticeauthormsg'] =
          abbr.length <= 100 ? abbr : '${abbr.substring(0, 100)}…';
    }
    appendAttachNewFields(data, attachmentIds);

    try {
      final response = await _httpClient.post(
        ApiConfig.webReplySubmitUrl(fid: fid, tid: tid),
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          headers: {
            'Referer': ApiConfig.forumAttachmentReferer(fid: fid, tid: tid),
          },
        ),
      );
      return DiscuzParser.parseReplyResponse(response.data);
    } catch (e, st) {
      if (isTransportUncertainError(e)) {
        talker.handle(e, st, 'sendReplyViaWeb transport uncertain');
        return const ReplySubmitResult.uncertain(
          '回复请求状态不确定，请返回主题刷新确认后再决定是否重发',
        );
      }
      return ReplySubmitResult.rejected(friendlyError(e, '回复', st));
    }
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
      return const ReplySubmitResult.rejected(
        '无法获取表单验证串，请刷新主题页后重试',
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
      return const ReplySubmitResult.rejected('服务器返回异常');
    }
    return DiscuzParser.parseReplyResponse(responseData);
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
    return DiscuzParser.parsePollVoteResponse(data);
  }

  // ── 评分（战斗力）──────────────────────────────────────────

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

      return DiscuzParser.parseRateFormResponse(body);
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
      return DiscuzParser.parseRateSubmitResponse(body);
    } catch (e) {
      if (e is LoginRequiredException) return '请先登录';
      return friendlyError(e, '评分');
    }
  }

  /// 预取 Discuz 举报表单及其隐藏字段。
  Future<ReportFormOptions> fetchReportForm({
    required String tid,
    required String pid,
    String? fid,
    int page = 1,
  }) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.reportFormUrl(tid: tid, pid: pid, fid: fid),
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data?.toString() ?? '';
      return DiscuzParser.parseReportFormResponse(body, tid: tid, page: page);
    } catch (e) {
      if (e is LoginRequiredException) {
        return ReportFormOptions.withDefaults(error: '请先登录');
      }
      return ReportFormOptions.withDefaults(
        error: friendlyError(e, '获取举报表单'),
        retryable: true,
      );
    }
  }

  /// 提交举报。成功返回 null，失败返回用户可见错误。
  Future<String?> submitReport({
    required String tid,
    required String pid,
    String? fid,
    required String reason,
    required String message,
    required ReportFormOptions form,
  }) async {
    final trimmedMessage = message.trim();
    final data = <String, String>{
      ...form.fields,
      'tid': form.fields['tid'] ?? tid,
      'rid': form.fields['rid'] ?? pid,
      'rtype': form.fields['rtype'] ?? 'post',
      'reportsubmit': 'true',
      'report_select': reason,
      'message': trimmedMessage.length > 200
          ? trimmedMessage.substring(0, 200)
          : trimmedMessage,
    };
    if (fid != null && fid.isNotEmpty) data['fid'] ??= fid;
    try {
      final response = await _httpClient.post(
        ApiConfig.reportSubmitUrl(),
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      return DiscuzParser.parseReportSubmitResponse(
        response.data?.toString() ?? '',
      );
    } catch (e) {
      if (e is LoginRequiredException) return '请先登录';
      return friendlyError(e, '举报');
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
    return DiscuzParser.parseSpaceList(json, type: type, page: page);
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
    return DiscuzParser.parseSpaceHtml(html, type: type, page: page);
  }

  final Map<String, int> _pageCache = {};

  /// 定位特定回复所在的页码。
  ///
  /// 失败时抛出 [StateError]，不再静默回落为第 1 页。
  Future<int> locatePostPage(String tid, String pid) async {
    final cacheKey = '$tid:$pid';
    final cached = _pageCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse('${ApiConfig.baseUrl}/forum.php').replace(
      queryParameters: {
        'mod': 'redirect',
        'goto': 'findpost',
        'ptid': tid,
        'pid': pid,
      },
    );
    final url = uri.toString();

    // Web：浏览器对跨域 301 + followRedirects=false 常得到 opaque 空响应；
    // 开发代理会把 findpost 改成 200 + X-S1-Locate-Page。仍设 followRedirects=true 作兜底。
    final response = await _httpClient.get(
      url,
      options: Options(
        followRedirects: kIsWeb,
        validateStatus: (s) => s != null && s < 500,
        responseType: ResponseType.plain,
      ),
    );

    int? resolved;

    // 代理改写的页码头（Web 首选）。
    final headerPage = response.headers.value('x-s1-locate-page');
    if (headerPage != null) {
      final page = int.tryParse(headerPage);
      if (page != null && page >= 1) {
        resolved = page;
      }
    }

    final location = response.headers.value('location');
    if (resolved == null && location != null) {
      resolved = pageFromFindpostLocation(location, expectedTid: tid);
    }

    // 浏览器已跟随 302 时 Location 不可读，改用最终 URI（常含 page=）。
    if (resolved == null) {
      final real = response.realUri;
      if (real.toString() != url &&
          (real.path.contains('viewthread') ||
              real.path.contains('thread-') ||
              real.queryParameters.containsKey('page') ||
              real.queryParameters.containsKey('tid'))) {
        resolved = pageFromFindpostLocation(real.toString(), expectedTid: tid);
      }
    }

    // HTML：div.pg；单页帖无分页控件时视为第 1 页。
    if (resolved == null) {
      final html = response.data as String? ?? '';
      resolved = pageFromViewthreadHtml(html);
    }

    if (resolved != null) {
      _pageCache[cacheKey] = resolved;
      return resolved;
    }

    throw StateError('locatePostPage failed for tid=$tid pid=$pid');
  }

  /// 从 findpost 的 Location 解析页码。
  ///
  /// S1/Discuz 对首页楼层常返回 `page=0` 或省略 `page`；二者均视为第 1 页。
  static int? pageFromFindpostLocation(
    String location, {
    String? expectedTid,
  }) {
    final redirected = Uri.parse(location);
    final pageParam = redirected.queryParameters['page'];
    final fromQuery = int.tryParse(pageParam ?? '');
    final fromPath = _pageFromPseudoStaticPath(redirected.path);

    int? page = fromQuery ?? fromPath;
    if (page != null) {
      // Discuz：首页重定向用 page=0（或负值异常），归一为 1。
      if (page < 1) page = 1;
      return page;
    }

    // 无 page 的同帖 viewthread / 伪静态链接触发：视为第 1 页。
    if (expectedTid != null &&
        expectedTid.isNotEmpty &&
        _isViewthreadLocationForTid(redirected, expectedTid)) {
      return 1;
    }
    return null;
  }

  /// 从已加载的 viewthread HTML 解析当前页（`div.pg > strong`）。
  ///
  /// 单页帖常只有空的 `div.pgt`、没有 `div.pg`，此时若能确认是读帖页则返回 1。
  static int? pageFromViewthreadHtml(String html) {
    if (html.isEmpty) return null;
    final pgMatch = RegExp(
      r'<div[^>]*class="[^"]*\bpg\b[^"]*"[^>]*>[\s\S]*?<strong[^>]*>\s*(\d+)\s*</strong>',
      caseSensitive: false,
    ).firstMatch(html);
    if (pgMatch != null) {
      final page = int.tryParse(pgMatch.group(1) ?? '');
      if (page != null) return page < 1 ? 1 : page;
    }
    final looksLikeViewthread = html.contains('id="postlist"') ||
        html.contains('pg_viewthread') ||
        html.contains('id="post_');
    if (looksLikeViewthread) return 1;
    return null;
  }

  static bool _isViewthreadLocationForTid(Uri location, String tid) {
    final qTid = location.queryParameters['tid'];
    if (qTid == tid) return true;
    final pathMatch =
        RegExp('thread-$tid-(\\d+)-\\d+\\.html').firstMatch(location.path);
    return pathMatch != null;
  }

  /// 解析 `thread-{tid}-{page}-1.html` 伪静态路径中的页码。
  static int? _pageFromPseudoStaticPath(String path) {
    final match = RegExp(r'thread-\d+-(\d+)-\d+\.html').firstMatch(path);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
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
      final result = DiscuzParser.parsePmListJson(json, page: page);
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
    return DiscuzParser.parsePmListHtml(html, page: page);
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
    return DiscuzParser.parsePmConversationJson(
      json,
      partnerUid: touid,
      page: page,
    );
  }

  Future<PmSendFormInfo> fetchPmSendForm() async {
    try {
      final response = await _httpClient.get(
        buildApiUrl(module: ApiConfig.moduleSendMessage),
      );
      _httpClient.cacheFormhashFromResponse(response.data);
      final result = DiscuzParser.parsePmSendForm(ensureJson(response.data));
      if (result.formhash == null || result.formhash!.trim().isEmpty) {
        return PmSendFormInfo(error: result.error ?? '无法获取私信表单验证串');
      }
      return result;
    } catch (e, st) {
      return PmSendFormInfo(error: friendlyError(e, '加载私信表单', st));
    }
  }

  Future<PmSendResult> sendPrivateMessage({
    required String touid,
    required String message,
  }) async {
    final recipient = touid.trim();
    final content = message.trim();
    if (recipient.isEmpty) return const PmSendResult.rejected('缺少收件人');
    if (!RegExp(r'^\d+$').hasMatch(recipient)) {
      return const PmSendResult.rejected('收件人无效');
    }
    if (content.isEmpty) return const PmSendResult.rejected('请输入私信内容');

    final form = await fetchPmSendForm();
    if (!form.canSend) {
      return PmSendResult.rejected(form.error ?? '当前无法发送私信');
    }

    final url = buildApiUrl(
      module: ApiConfig.moduleSendMessage,
      params: {'pmsubmit': 'true'},
    );
    try {
      final response = await _httpClient.post(
        url,
        data: <String, String>{
          'formhash': form.formhash!,
          'touid': recipient,
          'message': content,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return DiscuzParser.parsePmSendResponse(response.data);
    } catch (e, st) {
      talker.handle(e, st, 'sendPrivateMessage uncertain');
      return const PmSendResult.uncertain('发送状态未知，请刷新会话确认后再决定是否重试');
    }
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
      return DiscuzParser.parseNoticeListJson(json, page: page);
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
    return DiscuzParser.parseNoticeListHtml(html, page: page);
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
    return DiscuzParser.parseFavoriteThreadListJson(json, page: page);
  }

  Future<FavoriteListResult> _getFavoriteForumListJson({int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleMyFavForum,
      params: {'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    final json = ensureJson(response.data);
    checkAuthError(json);
    return DiscuzParser.parseFavoriteForumListJson(json, page: page);
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
    return DiscuzParser.parseFavoriteListHtml(html, page: page);
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
      return DiscuzParser.parseFavoriteMutationResponse(body);
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
      final result = DiscuzParser.parseFavoriteMutationResponse(body);
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
      return DiscuzParser.parseFavoriteMutationResponse(
        postResponse.data?.toString() ?? '',
      );
    } catch (e) {
      if (e is LoginRequiredException) {
        return const FavoriteMutationResult(error: '请先登录');
      }
      return FavoriteMutationResult(error: friendlyError(e, '取消收藏'));
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
  /// 桌面 UA POST `formhash` + [ForumSearchQuery.toPostFields]；跟随 302；
  /// 若返回触屏「无手机页面」提示则继续 GET `forcemobile=1` 桌面结果。
  /// 翻页：GET [pageHref] 模板。
  Future<ForumSearchPage> searchForum({
    required ForumSearchQuery query,
    int page = 1,
    String? pageHref,
  }) async {
    final validationError = query.validate();
    if (validationError != null) {
      return ForumSearchPage(error: validationError);
    }

    if (page > 1 && (pageHref == null || pageHref.isEmpty)) {
      return const ForumSearchPage(error: '无法翻页，请重新搜索');
    }

    try {
      final String body;
      if (page > 1) {
        final url = DiscuzParser.resolveSearchPageUrl(pageHref!, page);
        final response = await _httpClient.get(
          url,
          options: _searchHtmlGetOptions(),
        );
        body = await _followDesktopSearchTemplateIfNeeded(
          response.data?.toString() ?? '',
        );
      } else {
        body = await _submitDiscuzSearch(
          url: ApiConfig.searchForumUrl(),
          fields: query.toPostFields(),
        );
      }
      return DiscuzParser.parseForumSearchHtml(body);
    } on _SearchRequestException catch (e) {
      return ForumSearchPage(error: e.message);
    } on LoginRequiredException {
      rethrow;
    } catch (e, st) {
      return ForumSearchPage(error: friendlyError(e, '搜索主题', st));
    }
  }

  /// 用户搜索（`search.php?mod=user`）。
  ///
  /// 与 S1-Next 对齐：桌面 UA + `formhash`/`srchtxt`；触屏跳转页继续桌面模板。
  Future<UserSearchPage> searchUser({required String query}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const UserSearchPage(error: '请输入搜索关键词');
    }

    try {
      final body = await _submitDiscuzSearch(
        url: ApiConfig.searchUserUrl(),
        fields: {
          'srchtxt': trimmed,
          'searchsubmit': 'yes',
        },
      );
      return DiscuzParser.parseUserSearchHtml(body);
    } on _SearchRequestException catch (e) {
      return UserSearchPage(error: e.message);
    } on LoginRequiredException {
      rethrow;
    } catch (e, st) {
      return UserSearchPage(error: friendlyError(e, '搜索用户', st));
    }
  }

  static Options _searchHtmlPostOptions() => Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
        listFormat: ListFormat.multiCompatible,
        extra: const {'s1DesktopUa': true},
      );

  static Options _searchHtmlGetOptions() => Options(
        responseType: ResponseType.plain,
        extra: const {'s1DesktopUa': true},
      );

  Future<String> _submitDiscuzSearch({
    required String url,
    required Map<String, dynamic> fields,
  }) async {
    final formhash = await _prepareSearchFormhash();
    if (formhash == null) {
      throw const _SearchRequestException('无法获取表单验证串，请刷新后重试');
    }
    final response = await _httpClient.post(
      url,
      data: <String, dynamic>{
        'formhash': formhash,
        ...fields,
      },
      options: _searchHtmlPostOptions(),
    );
    var body = await _fetchSearchHtmlBody(response);
    return _followDesktopSearchTemplateIfNeeded(body);
  }

  Future<String?> _prepareSearchFormhash() async {
    final hasFormhash = await _httpClient.ensureFormhash(force: true);
    if (!hasFormhash) return null;
    final formhash = _httpClient.currentFormhash;
    return formhash.isEmpty ? null : formhash;
  }

  Future<String> _fetchSearchHtmlBody(Response<dynamic> response) async {
    if (response.statusCode != null &&
        response.statusCode! >= 300 &&
        response.statusCode! < 400) {
      final redirectUrl = DiscuzParser.resolveSearchRedirectUrl(
        response.headers.value('location'),
      );
      if (redirectUrl == null) {
        throw const _SearchRequestException('搜索结果跳转地址无效，请稍后重试');
      }
      final redirectResponse = await _httpClient.get(
        redirectUrl,
        options: _searchHtmlGetOptions(),
      );
      return redirectResponse.data?.toString() ?? '';
    }
    return response.data?.toString() ?? '';
  }

  Future<String> _followDesktopSearchTemplateIfNeeded(String body) async {
    final forcedDesktopUrl = DiscuzParser.extractForcedDesktopUrl(body);
    if (forcedDesktopUrl == null) return body;
    final forcedResponse = await _httpClient.get(
      forcedDesktopUrl,
      options: _searchHtmlGetOptions(),
    );
    return forcedResponse.data?.toString() ?? body;
  }
}

class _SearchRequestException implements Exception {
  const _SearchRequestException(this.message);
  final String message;
}
