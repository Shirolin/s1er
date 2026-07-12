import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/rate_log_service.dart';

void main() {
  group('RateLogService.parseRateLogs', () {
    test('parses rate log block with multiple entries', () {
      const html = '''
<div id="ratelog_67953733">
  <ul class="post_box cl">
    <li class="flex-box mli p0">
      <div class="flex-2"><a> 参与人数 <span class="xi1">4</span></a></div>
      <div class="flex-2">战斗力 <i><span class="xi1">+4</span></i></div>
      <div class="flex-3">理由</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=100">rustincohle</a></div>
      <div class="flex-2 xi1"> + 2</div>
      <div class="flex-3">好评加鹅</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=200">anotheruser</a></div>
      <div class="flex-2 xi1"> + 3</div>
      <div class="flex-3">精彩回复</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=300">user3</a></div>
      <div class="flex-2 xi1"> + 1</div>
      <div class="flex-3"></div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=400">user4</a></div>
      <div class="flex-2 xi1"> - 2</div>
      <div class="flex-3">扣分理由</div>
    </li>
  </ul>
</div>
''';

      final result = RateLogService.parseRateLogs(html);

      expect(result, contains('67953733'));
      final rateLog = result['67953733']!;
      expect(rateLog.participantCount, 4);
      expect(rateLog.totalScore, 4); // +2+3+1-2 = 4
      expect(rateLog.entries.length, 4);

      expect(rateLog.entries[0].username, 'rustincohle');
      expect(rateLog.entries[0].uid, '100');
      expect(rateLog.entries[0].score, 2);
      expect(rateLog.entries[0].reason, '好评加鹅');

      expect(rateLog.entries[1].username, 'anotheruser');
      expect(rateLog.entries[1].uid, '200');
      expect(rateLog.entries[1].score, 3);
      expect(rateLog.entries[1].reason, '精彩回复');

      expect(rateLog.entries[2].username, 'user3');
      expect(rateLog.entries[2].score, 1);
      expect(rateLog.entries[2].reason, '');

      expect(rateLog.entries[3].username, 'user4');
      expect(rateLog.entries[3].score, -2);
      expect(rateLog.entries[3].reason, '扣分理由');
    });

    test('parses multiple rate log blocks', () {
      const html = '''
<div id="ratelog_111">
  <ul class="post_box cl">
    <li class="flex-box mli p0">
      <div class="flex-2"><a> 参与人数 <span class="xi1">1</span></a></div>
      <div class="flex-2">战斗力 <i><span class="xi1">+2</span></i></div>
      <div class="flex-3">理由</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=1">userA</a></div>
      <div class="flex-2 xi1"> + 2</div>
      <div class="flex-3">good</div>
    </li>
  </ul>
</div>
<div id="ratelog_222">
  <ul class="post_box cl">
    <li class="flex-box mli p0">
      <div class="flex-2"><a> 参与人数 <span class="xi1">1</span></a></div>
      <div class="flex-2">战斗力 <i><span class="xi1">-1</span></i></div>
      <div class="flex-3">理由</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=2">userB</a></div>
      <div class="flex-2 xi1"> - 1</div>
      <div class="flex-3">bad</div>
    </li>
  </ul>
</div>
''';

      final result = RateLogService.parseRateLogs(html);

      expect(result.length, 2);
      expect(result['111']!.entries[0].username, 'userA');
      expect(result['111']!.totalScore, 2);
      expect(result['222']!.entries[0].username, 'userB');
      expect(result['222']!.totalScore, -1);
    });

    test('returns empty map for HTML without rate logs', () {
      const html =
          '<html><body><div class="postcontent">hello</div></body></html>';
      final result = RateLogService.parseRateLogs(html);
      expect(result, isEmpty);
    });

    test('returns empty map for empty string', () {
      final result = RateLogService.parseRateLogs('');
      expect(result, isEmpty);
    });

    test('handles score with no sign prefix', () {
      const html = '''
<div id="ratelog_999">
  <ul class="post_box cl">
    <li class="flex-box mli p0">
      <div class="flex-2"><a> 参与人数 <span class="xi1">1</span></a></div>
      <div class="flex-2">战斗力 <i><span class="xi1">5</span></i></div>
      <div class="flex-3">理由</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=1">user</a></div>
      <div class="flex-2 xi1"> 5</div>
      <div class="flex-3">nice</div>
    </li>
  </ul>
</div>
''';

      final result = RateLogService.parseRateLogs(html);
      expect(result['999']!.entries[0].score, 5);
      expect(result['999']!.totalScore, 5);
    });

    test('skips entries with missing username or score', () {
      const html = '''
<div id="ratelog_500">
  <ul class="post_box cl">
    <li class="flex-box mli p0">
      <div class="flex-2"><a> 参与人数 <span class="xi1">1</span></a></div>
      <div class="flex-2">战斗力 <i><span class="xi1">+2</span></i></div>
      <div class="flex-3">理由</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=1">validuser</a></div>
      <div class="flex-2 xi1"> + 2</div>
      <div class="flex-3">ok</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2">no link here</div>
      <div class="flex-2 xi1"> + 1</div>
      <div class="flex-3">skipped</div>
    </li>
  </ul>
</div>
''';

      final result = RateLogService.parseRateLogs(html);
      expect(result['500']!.entries.length, 1);
      expect(result['500']!.entries[0].username, 'validuser');
    });

    test('parses viewratings table with uid and timestamp', () {
      const html = '''
<table>
  <tbody>
    <tr>
      <td>战斗力 +2</td>
      <td><a href="home.php?mod=space&uid=100">rustincohle</a></td>
      <td>2018-4-14 22:20</td>
      <td>好评加鹅</td>
    </tr>
    <tr>
      <td>战斗力 -1</td>
      <td><a href="home.php?mod=space&uid=200">another</a></td>
      <td>2018-04-15 09:05</td>
      <td>扣分</td>
    </tr>
  </tbody>
</table>
''';

      final result =
          RateLogService.parseRateLogs(html, fallbackPid: '67953733');
      final rateLog = result['67953733']!;

      expect(rateLog.participantCount, 2);
      expect(rateLog.totalScore, 1);
      expect(rateLog.entries[0].uid, '100');
      expect(rateLog.entries[0].username, 'rustincohle');
      expect(rateLog.entries[0].score, 2);
      expect(rateLog.entries[0].ratedAt, DateTime(2018, 4, 14, 22, 20));
      expect(rateLog.entries[1].uid, '200');
      expect(rateLog.entries[1].score, -1);
      expect(rateLog.entries[1].ratedAt, DateTime(2018, 4, 15, 9, 5));
    });
  });
}
