import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import '../config/api_config.dart';
import '../models/rate_log.dart';
import 'http_client.dart';

class RateLogService {
  RateLogService(this._httpClient);
  final S1HttpClient _httpClient;

  static String _buildUrl(String tid, {int page = 1}) {
    return '${ApiConfig.forumPostUrl}'
        '?mod=viewthread&tid=$tid&page=$page&mobile=2';
  }

  Future<Map<String, PostRateLog>> fetchRateLogs(
    String tid, {
    int page = 1,
  }) async {
    try {
      final url = _buildUrl(tid, page: page);
      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data as String;
      return parseRateLogs(html);
    } catch (_) {
      return {};
    }
  }

  /// 获取特定帖子的完整评分记录
  Future<PostRateLog?> fetchFullRateLog(String tid, String pid) async {
    try {
      final url = '${ApiConfig.forumPostUrl}'
          '?mod=misc&action=viewratings&tid=$tid&pid=$pid&mobile=2';
      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data as String;
      final results = parseRateLogs(html, fallbackPid: pid);
      return results[pid];
    } catch (_) {
      return null;
    }
  }

  static Map<String, PostRateLog> parseRateLogs(
    String html, {
    String? fallbackPid,
  }) {
    final result = <String, PostRateLog>{};
    if (html.isEmpty) return result;

    try {
      final doc = parse(html);
      final ratelogDivs = doc.querySelectorAll('[id^=ratelog_]');

      for (final div in ratelogDivs) {
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
                final m = RegExp(r'([+-]?\s*\d+)').firstMatch(
                  dText.replaceAll('战斗力', ''),
                );
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
          final uid = _parseUid(link.attributes['href']);

          final score = _parseScore(divs[1].text);

          String reason = '';
          if (divs.length >= 3) {
            reason = divs[2].text.trim();
          }

          entries.add(
            RateLog(
              uid: uid,
              username: username,
              score: score,
              reason: reason,
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
    } catch (_) {}

    if (result.isEmpty && fallbackPid != null && fallbackPid.isNotEmpty) {
      final entries = _parseRatingTable(html);
      if (entries.isNotEmpty) {
        result[fallbackPid] = PostRateLog(
          pid: fallbackPid,
          entries: entries,
          totalScore: entries.fold<int>(0, (sum, entry) => sum + entry.score),
          participantCount: entries.length,
        );
      }
    }

    return result;
  }

  static List<RateLog> _parseRatingTable(String html) {
    try {
      final doc = parse(html);
      return doc
          .querySelectorAll('table tbody tr')
          .map((row) {
            final cells = row.children;
            if (cells.length < 4) return null;

            final link = cells[1].querySelector('a');
            final username = link?.text.trim() ?? '';
            if (username.isEmpty) return null;

            return RateLog(
              uid: _parseUid(link?.attributes['href']),
              username: username,
              score: _parseScore(cells[0].text),
              ratedAt: _parseRatedAt(cells[2].text),
              reason: cells[3].text.trim(),
            );
          })
          .whereType<RateLog>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int _parseScore(String raw) {
    final cleaned = raw.replaceAll(' ', '');
    final match = RegExp(r'[+-]?\d+').firstMatch(cleaned);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  static String? _parseUid(String? href) {
    if (href == null || href.isEmpty) return null;
    return RegExp(r'uid=(\d+)').firstMatch(href)?.group(1);
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
