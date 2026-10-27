import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

import '../config/api_config.dart';
import '../models/rate_log.dart';
import 'http_client.dart';

class RateLogService {
  RateLogService(this._httpClient);
  final S1HttpClient _httpClient;

  /// `inajax=1` 只返回评分表格片段；`mobile=no` 保留桌面 `<table>`，
  /// 带 `space-uid-<uid>.html` 链接且比移动弹层更小（约 1 KB）。
  static String _buildUrl(String tid, String pid) {
    return '${ApiConfig.forumPostUrl}'
        '?mod=misc&action=viewratings&tid=$tid&pid=$pid'
        '&inajax=1&mobile=no';
  }

  /// 获取单楼完整评分记录；该楼无评分或请求失败时返回 null。
  Future<PostRateLog?> fetchFullRateLog(String tid, String pid) async {
    try {
      final response = await _httpClient.get(
        _buildUrl(tid, pid),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data as String;
      return parseRateTable(html, pid: pid);
    } catch (_) {
      return null;
    }
  }

  /// 解析 `misc&action=viewratings&inajax=1&mobile=no` 的桌面表格片段。
  ///
  /// 列顺序：积分 / 用户名 / 时间 / 理由。表头行也是 `<td>`，靠用户名列
  /// 没有 `<a>` 链接过滤掉。服务端不返回参与人数，故以条目数计。
  static PostRateLog? parseRateTable(String html, {required String pid}) {
    if (html.isEmpty) return null;

    try {
      final doc = parse(html);
      var rows = doc.querySelectorAll('table tbody tr');
      // html5 解析通常会补 tbody；保留回退以兼容异常片段。
      if (rows.isEmpty) rows = doc.querySelectorAll('table tr');
      if (rows.isEmpty) return null;

      final entries = <RateLog>[];
      for (final row in rows) {
        final cells = row.children;
        if (cells.length < 4) continue;

        final link = cells[1].querySelector('a');
        if (link == null) continue;
        final username = link.text.trim();
        if (username.isEmpty) continue;

        entries.add(
          RateLog(
            uid: _parseUid(link.attributes['href']),
            username: username,
            score: _parseScore(cells[0].text),
            ratedAt: _parseRatedAt(cells[2].text),
            reason: cells[3].text.trim(),
          ),
        );
      }

      if (entries.isEmpty) return null;

      return PostRateLog(
        pid: pid,
        entries: entries,
        totalScore: entries.fold<int>(0, (sum, entry) => sum + entry.score),
        participantCount: entries.length,
      );
    } catch (_) {
      return null;
    }
  }

  static int _parseScore(String raw) {
    final cleaned = raw.replaceAll(' ', '');
    final match = RegExp(r'[+-]?\d+').firstMatch(cleaned);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  static String? _parseUid(String? href) {
    if (href == null || href.isEmpty) return null;
    return RegExp(r'(?:uid=|space-uid-)(\d+)').firstMatch(href)?.group(1);
  }

  static DateTime? _parseRatedAt(String raw) {
    final match = RegExp(
      r'(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final parts = List.generate(
      5,
      (index) => int.tryParse(match.group(index + 1) ?? ''),
    );
    if (parts.any((part) => part == null)) return null;
    return DateTime(parts[0]!, parts[1]!, parts[2]!, parts[3]!, parts[4]!);
  }
}
