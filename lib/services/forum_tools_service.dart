import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/app_exceptions.dart';
import '../models/attendance_result.dart';
import '../models/dark_room_entry.dart';
import '../models/friend_summary.dart';
import '../models/server_blacklist.dart';
import '../utils/error_handler.dart';
import 'http_client.dart';

/// 低频论坛工具：好友列表、每日签到、小黑屋。
class ForumToolsService {
  ForumToolsService(this._httpClient);

  final S1HttpClient _httpClient;

  Future<FriendListResult> getFriendList({required String uid}) async {
    final url = ApiServiceCompat.buildApiUrl(
      module: ApiConfig.moduleFriend,
      version: ApiConfig.friendApiVersion,
      params: {'uid': uid},
    );
    try {
      final response = await _httpClient.get(url);
      final json = ensureJson(response.data);
      return parseFriendListJson(json);
    } catch (e, st) {
      if (e is LoginRequiredException) rethrow;
      throw Exception(friendlyError(e, '好友列表', st));
    }
  }

  Future<ServerBlacklistPage> getServerBlacklistPage({
    required String uid,
    required int page,
  }) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.serverBlacklistUrl(uid: uid, page: page),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data?.toString() ?? '';
      if (html.contains('id="loginform') ||
          html.contains("id='loginform") ||
          html.contains('name="login"')) {
        throw LoginRequiredException();
      }
      return ServerBlacklistPage.fromHtml(html, page: page);
    } catch (e, st) {
      if (e is LoginRequiredException) rethrow;
      throw Exception(friendlyError(e, '网页黑名单', st));
    }
  }

  /// 用户显式点击后调用；GET 会产生服务端签到写入，失败不自动重试。
  Future<AttendanceResult> dailySign() async {
    final formhash = await _httpClient.requireFormhash();
    if (formhash == null) {
      return const AttendanceResult(
        outcome: AttendanceOutcome.failed,
        message: '无法获取表单验证串，请刷新后重试',
      );
    }

    final url = ApiConfig.dailyAttendanceUrl(formhash: formhash);
    try {
      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return parseAttendanceResponse(response.data?.toString() ?? '');
    } catch (e, st) {
      return AttendanceResult(
        outcome: AttendanceOutcome.failed,
        message: friendlyError(e, '每日签到', st),
      );
    }
  }

  Future<DarkRoomPage> getDarkRoom({String? cursor}) async {
    final url = ApiConfig.darkRoomUrl(cursor: cursor);
    try {
      // S1 returns bare numeric object keys (for example, {576523: ...}),
      // which are not valid JSON. Keep the raw body so [ensureJson] can
      // normalize it before Dart decodes it; Android Dio otherwise decodes
      // application/json eagerly and throws first.
      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final json = ensureJson(response.data);
      return parseDarkRoomJson(json, requestCursor: cursor);
    } catch (e, st) {
      if (e is LoginRequiredException || e is ServerMaintenanceException) {
        rethrow;
      }
      throw Exception(friendlyError(e, '小黑屋', st));
    }
  }

  static FriendListResult parseFriendListJson(Map<String, dynamic> json) {
    final message = json['Message'];
    if (message is Map) {
      final messageval = message['messageval']?.toString() ?? '';
      if (messageval.contains('login_before_enter_home') ||
          messageval.contains('to_login')) {
        throw LoginRequiredException();
      }
    }
    if (json['error']?.toString().contains('to_login') == true) {
      throw LoginRequiredException();
    }

    final variables = json['Variables'];
    if (variables is! Map) return FriendListResult.empty;
    final rawList = variables['list'];
    final items = <FriendSummary>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          final friend = FriendSummary.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (friend.uid.isNotEmpty) items.add(friend);
        }
      }
    } else if (rawList is Map) {
      for (final value in rawList.values) {
        if (value is Map) {
          final friend = FriendSummary.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (friend.uid.isNotEmpty) items.add(friend);
        }
      }
    }
    final count = int.tryParse(variables['count']?.toString() ?? '');
    return FriendListResult(items: items, count: count);
  }

  static AttendanceResult parseAttendanceResponse(String body) {
    final html = _unwrapAjaxHtml(body);
    if (html.trim().isEmpty) {
      return const AttendanceResult(
        outcome: AttendanceOutcome.unknown,
        message: '无数据！',
      );
    }

    final succeed = _extractHandlerMessage(
      html,
      handlerPrefix: 'succeedhandle_',
      messageIndex: 1,
    );
    if (succeed != null) {
      final already = succeed.contains('已签到');
      return AttendanceResult(
        outcome: already
            ? AttendanceOutcome.alreadySigned
            : AttendanceOutcome.signedNow,
        message: succeed.isEmpty ? '签到成功' : succeed,
      );
    }

    final error = _extractHandlerMessage(
      html,
      handlerPrefix: 'errorhandle_',
      messageIndex: 0,
    );
    if (error != null) {
      final already = error.contains('已签到');
      return AttendanceResult(
        outcome: already
            ? AttendanceOutcome.alreadySigned
            : AttendanceOutcome.failed,
        message: error.isEmpty ? html : error,
      );
    }

    if (html.contains('已签到')) {
      return AttendanceResult(
        outcome: AttendanceOutcome.alreadySigned,
        message: html.trim(),
      );
    }

    return AttendanceResult(
      outcome: AttendanceOutcome.unknown,
      message: html.trim().isEmpty ? '服务器返回异常' : html.trim(),
    );
  }

  static DarkRoomPage parseDarkRoomJson(
    Map<String, dynamic> json, {
    String? requestCursor,
  }) {
    if (json['error']?.toString() == 'to_login' ||
        (json['Message'] is Map &&
            (json['Message'] as Map)['messageval']?.toString().contains(
                      'to_login',
                    ) ==
                true)) {
      throw LoginRequiredException();
    }

    final items = <DarkRoomEntry>[];
    final data = json['data'];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          items.add(DarkRoomEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } else if (data is Map) {
      for (final value in data.values) {
        if (value is Map) {
          items.add(DarkRoomEntry.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }

    String? dataExist;
    String? nextCursor;
    final message = json['message']?.toString();
    if (message != null && message.isNotEmpty) {
      final parts = message.split('|');
      dataExist = parts.isNotEmpty ? parts[0] : null;
      nextCursor = parts.length > 1 ? parts[1] : null;
      if (nextCursor != null && nextCursor.isEmpty) nextCursor = null;
    }

    final request = requestCursor ?? '';
    final next = nextCursor ?? '';
    final hasMore = dataExist != '0' &&
        items.isNotEmpty &&
        next.isNotEmpty &&
        next != request;

    return DarkRoomPage(
      items: items,
      nextCursor: nextCursor,
      dataExist: dataExist,
      hasMore: hasMore,
    );
  }

  static Map<String, dynamic> ensureJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
        throw ServerMaintenanceException('服务器维护中，请稍后再试');
      }
      if (trimmed.contains('id="loginform_') ||
          trimmed.contains('name="login"')) {
        throw LoginRequiredException();
      }

      // 正则匹配裸数字键（如 {576523: 或 ,552941:），自动补齐双引号使之符合标准 JSON 格式
      final normalized = trimmed.replaceAllMapped(
        RegExp(r'([{,])\s*(\d+)\s*:'),
        (match) => '${match.group(1)}"${match.group(2)}":',
      );

      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    throw FormatException('Unexpected response type: ${data.runtimeType}');
  }

  static String _unwrapAjaxHtml(String body) {
    final cdataMatch = RegExp(
      r'<!\[CDATA\[(.*)\]\]>',
      dotAll: true,
    ).firstMatch(body);
    return cdataMatch?.group(1) ?? body;
  }

  /// Discuz Ajax handler 参数解析：按逗号切开，但尊重单引号字符串。
  static String? _extractHandlerMessage(
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

  static List<String> _splitAjaxParams(String raw) {
    final params = <String>[];
    final buffer = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch == "'" && (i == 0 || raw[i - 1] != '\\')) {
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

/// 仅复用 ApiService 的 URL builder，避免 ForumToolsService 依赖整份 ApiService。
class ApiServiceCompat {
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
}
