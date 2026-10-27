import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

import '../config/api_config.dart';
import '../models/rate_log.dart';
import 'http_client.dart';
import 'talker.dart';

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

  /// 获取单楼评分记录；该楼没有评分时返回 null。
  ///
  /// 传输/HTTP 异常向上抛，由 provider 记录并决定是否重试；不在此吞掉，
  /// 否则「无评分」和「请求失败」无法区分。
  Future<PostRateLog?> fetchRateLog(String tid, String pid) async {
    final response = await _httpClient.get(
      _buildUrl(tid, pid),
      options: Options(responseType: ResponseType.plain),
    );
    return parseRateTable(response.data as String, pid: pid);
  }

  /// 整页 HTML 兜底：解析 `viewthread&mobile=2` 里的 `#ratelog_<pid>`。
  ///
  /// 仅在 v4 `commentcount` 标记不可用（登录态下该页 v4 稳定 503）时调用，
  /// 正常页一律走 [fetchRateLog]，不产生这笔约 40 KB 的请求。
  Future<Map<String, PostRateLog>> fetchRateLogsByPage(
    String tid, {
    int page = 1,
  }) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.forumPostUrl}'
        '?mod=viewthread&tid=$tid&page=$page&mobile=2',
        options: Options(responseType: ResponseType.plain),
      );
      return parseRateLogBlocks(response.data as String);
    } catch (e, st) {
      talker.handle(e, st, 'fetchRateLogsByPage failed tid=$tid page=$page');
      return const {};
    }
  }

  /// 解析整页 HTML 中的 `#ratelog_<pid>` 区块（兜底路径专用）。
  static Map<String, PostRateLog> parseRateLogBlocks(String html) {
    final result = <String, PostRateLog>{};
    if (html.trim().isEmpty) return result;

    try {
      final doc = parse(html);
      for (final div in doc.querySelectorAll('[id^=ratelog_]')) {
        final pid = div.id.replaceFirst('ratelog_', '');
        if (pid.isEmpty) continue;

        final lis = div.querySelectorAll('li');
        if (lis.isEmpty) continue;

        final entries = <RateLog>[];
        int participantCount = 0;
        int totalScore = 0;

        for (final li in lis) {
          final liText = li.text;
          if (liText.contains('参与人数')) {
            for (final d in li.querySelectorAll('div')) {
              final dText = d.text;
              if (dText.contains('参与人数')) {
                final m = RegExp(r'(\d+)').firstMatch(dText);
                if (m != null) {
                  participantCount = int.tryParse(m.group(1) ?? '') ?? 0;
                }
              } else if (dText.contains('战斗力')) {
                final m = RegExp(r'([+-]?\s*\d+)')
                    .firstMatch(dText.replaceAll('战斗力', ''));
                if (m != null) {
                  totalScore = _parseScore(m.group(1) ?? '');
                }
              }
            }
            continue;
          }

          final divs = li.querySelectorAll('div');
          if (divs.length < 2) continue;

          final link = divs[0].querySelector('a');
          if (link == null) continue;
          final username = link.text.trim();
          if (username.isEmpty) continue;

          entries.add(
            RateLog(
              uid: _parseUid(link.attributes['href']),
              username: username,
              score: _parseScore(divs[1].text),
              reason: divs.length >= 3 ? divs[2].text.trim() : '',
            ),
          );
        }

        if (entries.isNotEmpty) {
          result[pid] = PostRateLog(
            pid: pid,
            entries: entries,
            totalScore: totalScore,
            participantCount: participantCount,
          );
        }
      }
    } catch (e, st) {
      talker.handle(e, st, 'parse rate log blocks failed');
    }

    return result;
  }

  /// 解析 `misc&action=viewratings&inajax=1&mobile=no` 的桌面表格片段。
  ///
  /// 列顺序：积分 / 用户名 / 时间 / 理由。表头行也是 `<td>`，靠用户名列
  /// 没有 `<a>` 链接过滤掉。服务端不返回参与人数，故以条目数计。
  ///
  /// 返回 null 表示「该楼确实没有评分」（未评分楼返回无表格的
  /// `…还没有评分记录` 提示）；其它无表格响应视为异常抛出，避免把错误
  /// 当成空结果缓存。
  static PostRateLog? parseRateTable(String html, {required String pid}) {
    final raw = html.trim();
    if (raw.isEmpty) {
      throw const FormatException('empty rate log response');
    }

    // `inajax=1` 返回 XML + CDATA；先剥掉壳再解析，避免 CDATA 起始符
    // 被当成 bogus comment 吞掉第一个标签。
    final cdata = RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>').firstMatch(raw);
    final body = (cdata?.group(1) ?? raw).trim();
    if (body.isEmpty) {
      throw const FormatException('empty rate log response');
    }

    final doc = parse(body);
    var rows = doc.querySelectorAll('table tbody tr');
    // html5 解析通常会补 tbody；保留回退以兼容异常片段。
    if (rows.isEmpty) rows = doc.querySelectorAll('table tr');
    if (rows.isEmpty) {
      if (body.contains('没有评分记录')) return null;
      throw const FormatException('rate log response has no ratings table');
    }

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
