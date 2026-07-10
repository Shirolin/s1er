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

  Future<Map<String, PostRateLog>> fetchRateLogs(String tid, {int page = 1}) async {
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

  static Map<String, PostRateLog> parseRateLogs(String html) {
    final result = <String, PostRateLog>{};
    if (html.isEmpty) return result;

    try {
      final doc = parse(html);
      final ratelogDivs = doc.querySelectorAll('*')
          .where((el) => el.id.startsWith('ratelog_'))
          .toList();

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

          final score = _parseScore(divs[1].text);

          String reason = '';
          if (divs.length >= 3) {
            reason = divs[2].text.trim();
          }

          entries.add(RateLog(
            username: username,
            score: score,
            reason: reason,
          ),);
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

    return result;
  }

  static int _parseScore(String raw) {
    final cleaned = raw.replaceAll(' ', '');
    return int.tryParse(cleaned) ?? 0;
  }
}
