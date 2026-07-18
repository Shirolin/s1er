import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/notice_item.dart';
import 'package:s1er/services/api_service.dart';

void main() {
  group('parsePmListHtml', () {
    late String html;

    setUp(() {
      html = File('test/fixtures/pm_list.html').readAsStringSync();
    });

    test('parses conversation list from mobile HTML', () {
      final result = ApiService.parsePmListHtml(html);

      expect(result.items.length, 2);

      final outgoing = result.items.first;
      expect(outgoing.touid, '535036');
      expect(outgoing.partnerName, 'Kiyohara_Yasuke');
      expect(outgoing.preview, '那就好');
      expect(outgoing.isOutgoing, isTrue);
      expect(outgoing.avatarUrl, contains('53/50/36'));

      final incoming = result.items[1];
      expect(incoming.touid, '194717');
      expect(incoming.partnerName, '忘却旋律');
      expect(incoming.preview, contains('上传好了不少'));
      expect(incoming.isOutgoing, isFalse);
    });
  });

  group('parseNoticeListHtml', () {
    late String html;

    setUp(() {
      html = File('test/fixtures/notice_list.html').readAsStringSync();
    });

    test('parses notice list with tid/pid and pagination', () {
      final result = ApiService.parseNoticeListHtml(html);

      expect(result.items.length, 2);
      expect(result.totalPages, 20);

      final reply = result.items.first;
      expect(reply.id, '18830194');
      expect(reply.authorUid, '565047');
      expect(reply.authorName, 'JOJOROY');
      expect(reply.tid, '2253488');
      expect(reply.pid, '69899250');
      expect(reply.type, NoticeType.reply);

      final rate = result.items[1];
      expect(rate.id, '18578067');
      expect(rate.tid, '2274556');
      expect(rate.pid, '69174843');
      expect(rate.type, NoticeType.rate);
    });
  });

  group('parsePmListJson', () {
    test('parses mypm API list fields', () {
      final json = {
        'Variables': {
          'list': [
            {
              'touid': '535036',
              'msgfrom': 'Kiyohara_Yasuke',
              'msgfromid': '535036',
              'tousername': 'Kiyohara_Yasuke',
              'message': '那就好',
              'dateline': '1718585640',
            },
            {
              'touid': '194717',
              'msgfrom': 'shirolin',
              'msgfromid': '426519',
              'tousername': '忘却旋律',
              'message': '感谢回复',
              'dateline': '1719216000',
            },
          ],
          'perpage': '20',
          'count': '2',
        },
      };

      final result = ApiService.parsePmListJson(json);

      expect(result.items.length, 2);
      expect(result.items.first.isOutgoing, isFalse);
      expect(result.items.last.isOutgoing, isTrue);
      expect(result.totalPages, 1);
    });

    test('parses alternate mypm field aliases', () {
      final json = {
        'Variables': {
          'list': [
            {
              'msgtoid': '194717',
              'msgfrom': '忘却旋律',
              'msgfromid': '194717',
              'lastsummary': '好的 明白了',
              'dbdateline': '1719216060',
              'avatar':
                  'https://avatar.stage1st.com/avatar.php?uid=194717&size=small',
            },
          ],
          'perpage': '20',
          'count': '1',
        },
      };

      final result = ApiService.parsePmListJson(json);
      final item = result.items.single;

      expect(item.touid, '194717');
      expect(item.partnerName, '忘却旋律');
      expect(item.preview, '好的 明白了');
      expect(item.isOutgoing, isFalse);
      expect(item.avatarUrl, contains('19/47/17'));
    });
  });

  group('parsePmConversationJson', () {
    test('parses messages, direction, entities and pagination', () {
      final json = jsonDecode(
        File('test/fixtures/pm_conversation.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final result = ApiService.parsePmConversationJson(
        json,
        partnerUid: '200001',
      );

      expect(result.items, hasLength(2));
      expect(result.items.first.isOutgoing, isFalse);
      expect(result.items.first.message, '收到 & 谢谢');
      expect(result.items.last.isOutgoing, isTrue);
      expect(result.items.last.message, '不客气\n稍后见');
      expect(result.totalPages, 1);
    });

    test('parses alternate conversation time fields', () {
      final result = ApiService.parsePmConversationJson(
        {
          'Variables': {
            'list': [
              {
                'pmid': '103',
                'msgfromid': '200001',
                'msgfrom': '示例用户',
                'message': '第一条',
                'dbdateline': '1719216060',
              },
              {
                'pmid': '104',
                'msgfromid': '200001',
                'msgfrom': '示例用户',
                'message': '第二条',
                'vdateline': '2025-6-17 09:34',
              },
            ],
            'perpage': '20',
            'count': '2',
          },
        },
        partnerUid: '200001',
      );

      expect(result.items.first.dateline, 1719216060);
      expect(
        result.items.last.dateline,
        DateTime(2025, 6, 17, 9, 34).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('rejects missing list and login responses', () {
      expect(
        () => ApiService.parsePmConversationJson(
          {'Variables': <String, dynamic>{}},
          partnerUid: '200001',
        ),
        throwsFormatException,
      );
      expect(
        () => ApiService.parsePmConversationJson(
          {
            'Message': {'messageval': 'login_before_enter_home'},
          },
          partnerUid: '200001',
        ),
        throwsA(isA<LoginRequiredException>()),
      );
    });
  });

  group('parseNoticeListJson', () {
    test('parses post notice and navigation target', () {
      final json = jsonDecode(
        File('test/fixtures/mynotelist_mypost.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final result = ApiService.parseNoticeListJson(json);
      final item = result.items.single;

      expect(item.authorName, '提醒用户');
      expect(item.tid, '400001');
      expect(item.pid, '500001');
      expect(item.type, NoticeType.reply);
      expect(item.isNew, isTrue);
      expect(item.canNavigate, isTrue);
    });

    test('accepts system notice without author or thread target', () {
      final json = jsonDecode(
        File('test/fixtures/mynotelist_system.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final item = ApiService.parseNoticeListJson(json).items.single;

      expect(item.authorName, '系统通知');
      expect(item.canNavigate, isFalse);
      expect(item.type, NoticeType.other);
    });

    test('treats a valid empty list as empty data', () {
      final result = ApiService.parseNoticeListJson({
        'Variables': {
          'list': <dynamic>[],
          'count': '0',
          'perpage': '20',
        },
      });

      expect(result.items, isEmpty);
      expect(result.totalPages, 1);
    });
  });
}
