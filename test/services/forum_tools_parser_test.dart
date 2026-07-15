import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/app_exceptions.dart';
import 'package:s1_app/models/attendance_result.dart';
import 'package:s1_app/services/forum_tools_service.dart';

void main() {
  group('parseFriendListJson', () {
    test('parses list of friends', () {
      final json =
          jsonDecode(File('test/fixtures/friend_list.json').readAsStringSync())
              as Map<String, dynamic>;
      final result = ForumToolsService.parseFriendListJson(json);
      expect(result.items, hasLength(2));
      expect(result.items.first.uid, '194717');
      expect(result.items.first.username, '忘却旋律');
      expect(result.count, 2);
      expect(result.items.first.avatarUrl, contains('19/47/17'));
    });

    test('parses map-shaped list', () {
      final result = ForumToolsService.parseFriendListJson({
        'Variables': {
          'list': {
            '0': {'uid': '1', 'username': 'a'},
            '1': {'uid': '2', 'username': 'b'},
          },
        },
      });
      expect(result.items.map((e) => e.uid), ['1', '2']);
    });

    test('throws LoginRequiredException', () {
      final json =
          jsonDecode(
                File(
                  'test/fixtures/friend_list_login_required.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        () => ForumToolsService.parseFriendListJson(json),
        throwsA(isA<LoginRequiredException>()),
      );
    });

    test('empty list with null count', () {
      final result = ForumToolsService.parseFriendListJson({
        'Variables': {'list': <dynamic>[], 'count': null},
      });
      expect(result.items, isEmpty);
      expect(result.count, isNull);
    });
  });

  group('parseAttendanceResponse', () {
    test('parses succeedhandle as signedNow', () {
      final body = File(
        'test/fixtures/daily_sign_success.xml',
      ).readAsStringSync();
      final result = ForumToolsService.parseAttendanceResponse(body);
      expect(result.outcome, AttendanceOutcome.signedNow);
      expect(result.message, contains('签到成功'));
      expect(result.isSignedToday, isTrue);
    });

    test('parses already signed errorhandle', () {
      final body = File(
        'test/fixtures/daily_sign_already.xml',
      ).readAsStringSync();
      final result = ForumToolsService.parseAttendanceResponse(body);
      expect(result.outcome, AttendanceOutcome.alreadySigned);
      expect(result.message, contains('已签到'));
    });

    test('parses generic errorhandle as failed', () {
      final body = File(
        'test/fixtures/daily_sign_error.xml',
      ).readAsStringSync();
      final result = ForumToolsService.parseAttendanceResponse(body);
      expect(result.outcome, AttendanceOutcome.failed);
      expect(result.message, contains('用户组不允许'));
    });

    test('handles commas inside quoted message', () {
      const body =
          "succeedhandle_x('','恭喜，今日签到成功，奖励：死鱼 1 条，积分 +2',{});";
      final result = ForumToolsService.parseAttendanceResponse(body);
      expect(result.outcome, AttendanceOutcome.signedNow);
      expect(result.message, contains('死鱼 1 条，积分 +2'));
    });

    test('empty body is unknown', () {
      final result = ForumToolsService.parseAttendanceResponse('');
      expect(result.outcome, AttendanceOutcome.unknown);
    });
  });

  group('parseDarkRoomJson', () {
    test('parses map data and message cursor', () {
      final json =
          jsonDecode(File('test/fixtures/dark_room.json').readAsStringSync())
              as Map<String, dynamic>;
      final page = ForumToolsService.parseDarkRoomJson(json);
      expect(page.items, hasLength(2));
      expect(page.nextCursor, '78648');
      expect(page.hasMore, isTrue);
      expect(page.items.first.action, '禁止发言');
      expect(page.items[1].isPermanent, isTrue);
      // cursor differs from last item cid
      expect(page.items.map((e) => e.cid), isNot(contains('78648')));
    });

    test('parses list-shaped data', () {
      final json =
          jsonDecode(
                File('test/fixtures/dark_room_list.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final page = ForumToolsService.parseDarkRoomJson(
        json,
        requestCursor: '78648',
      );
      expect(page.items.single.uid, '200002');
      expect(page.nextCursor, '78571');
      expect(page.hasMore, isTrue);
    });

    test('stops when cursor does not advance', () {
      final page = ForumToolsService.parseDarkRoomJson({
        'message': '1|100',
        'data': {
          '1': {
            'cid': '99',
            'uid': '1',
            'username': 'x',
            'operatorid': '',
            'operator': '',
            'action': '禁止发言',
            'reason': '',
            'dateline': '',
            'groupexpiry': '',
          },
        },
      },
        requestCursor: '100',
      );
      expect(page.hasMore, isFalse);
    });

    test('empty data has no more', () {
      final page = ForumToolsService.parseDarkRoomJson({
        'message': '0|',
        'data': <String, dynamic>{},
      });
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
