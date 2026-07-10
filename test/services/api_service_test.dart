import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('ApiService', () {
    group('buildApiUrl', () {
      test('builds correct API URL with module and params', () {
        final url = ApiService.buildApiUrl(
          module: 'forumdisplay',
          params: {'fid': '4', 'page': '1'},
        );
        expect(url, contains('module=forumdisplay'));
        expect(url, contains('fid=4'));
        expect(url, contains('page=1'));
      });

      test('includes version parameter', () {
        final url = ApiService.buildApiUrl(
          module: 'viewthread',
          params: {'tid': '123'},
        );
        expect(url, contains('version=4'));
      });

      test('builds URL with module only', () {
        final url = ApiService.buildApiUrl(module: 'forumindex');
        expect(url, contains('module=forumindex'));
        expect(url, contains('version=4'));
      });

      test('encodes parameter values', () {
        final url = ApiService.buildApiUrl(
          module: 'forumdisplay',
          params: {'fid': '4', 'filter': 'typeid&1'},
        );
        expect(url, contains('filter=typeid'));
        expect(url, contains('%26'));
      });

      test('starts with mobile API URL', () {
        final url = ApiService.buildApiUrl(module: 'forumindex');
        expect(url, startsWith('https://stage1st.com/2b/api/mobile/index.php'));
      });
    });

    group('parseThreadList', () {
      test('parses thread list from JSON', () {
        final json = {
          'Variables': {
            'forum_threadlist': [
              {
                'tid': '123',
                'subject': 'Test Thread',
                'author': 'user',
                'authorid': '1',
                'dateline': '1700000000',
                'views': '100',
                'replies': '5',
                'fid': '4',
              }
            ],
          },
        };
        final threads = ApiService.parseThreadList(json);
        expect(threads.length, 1);
        expect(threads[0].tid, '123');
        expect(threads[0].subject, 'Test Thread');
        expect(threads[0].author, 'user');
        expect(threads[0].views, 100);
        expect(threads[0].replies, 5);
        expect(threads[0].fid, '4');
      });

      test('parses multiple threads', () {
        final json = {
          'Variables': {
            'forum_threadlist': [
              {
                'tid': '1',
                'subject': 'Thread 1',
                'author': 'a',
                'authorid': '1',
                'dateline': '1700000000',
                'views': '10',
                'replies': '2',
                'fid': '4',
              },
              {
                'tid': '2',
                'subject': 'Thread 2',
                'author': 'b',
                'authorid': '2',
                'dateline': '1700000100',
                'views': '20',
                'replies': '3',
                'fid': '5',
              },
            ],
          },
        };
        final threads = ApiService.parseThreadList(json);
        expect(threads.length, 2);
        expect(threads[0].tid, '1');
        expect(threads[1].tid, '2');
      });

      test('returns empty list when Variables is missing', () {
        final json = <String, dynamic>{};
        final threads = ApiService.parseThreadList(json);
        expect(threads, isEmpty);
      });

      test('returns empty list when forum_threadlist is null', () {
        final json = {'Variables': <String, dynamic>{}};
        final threads = ApiService.parseThreadList(json);
        expect(threads, isEmpty);
      });

      test('handles threads with numeric values as strings', () {
        final json = {
          'Variables': {
            'forum_threadlist': [
              {
                'tid': 123,
                'subject': 'Test',
                'author': 'user',
                'authorid': 1,
                'dateline': 1700000000,
                'views': 100,
                'replies': 5,
                'fid': 4,
              }
            ],
          },
        };
        final threads = ApiService.parseThreadList(json);
        expect(threads.length, 1);
        expect(threads[0].tid, '123');
        expect(threads[0].views, 100);
      });
    });

    group('parsePostList', () {
      test('parses post list from JSON', () {
        final json = {
          'Variables': {
            'postlist': [
              {
                'pid': '67890',
                'message': 'Hello world',
                'author': 'user1',
                'authorid': '200',
                'dbdateline': '1700001000',
                'number': '1',
              }
            ],
          },
        };
        final posts = ApiService.parsePostList(json);
        expect(posts.length, 1);
        expect(posts[0].pid, '67890');
        expect(posts[0].message, 'Hello world');
        expect(posts[0].author, 'user1');
        expect(posts[0].floor, 1);
      });

      test('parses multiple posts', () {
        final json = {
          'Variables': {
            'postlist': [
              {
                'pid': '1',
                'message': 'Post 1',
                'author': 'a',
                'authorid': '1',
                'dateline': '1700000000',
                'floor': '1',
              },
              {
                'pid': '2',
                'message': 'Post 2',
                'author': 'b',
                'authorid': '2',
                'dateline': '1700001000',
                'floor': '2',
              },
            ],
          },
        };
        final posts = ApiService.parsePostList(json);
        expect(posts.length, 2);
        expect(posts[0].pid, '1');
        expect(posts[1].pid, '2');
      });

      test('returns empty list when postlist is missing', () {
        final json = {'Variables': <String, dynamic>{}};
        final posts = ApiService.parsePostList(json);
        expect(posts, isEmpty);
      });

      test('returns empty list when Variables is missing', () {
        final json = <String, dynamic>{};
        final posts = ApiService.parsePostList(json);
        expect(posts, isEmpty);
      });
    });

    group('parsePoll', () {
      test('parses poll from viewthread JSON when special is 1', () {
        final json = {
          'Variables': {
            'thread': {'special': '1'},
            'special_poll': {
              'polloptions': {
                '1': {
                  'polloptionid': '82378',
                  'polloption': '选项 A',
                  'votes': '80',
                  'percent': '12.50',
                  'color': 'E92725',
                },
              },
              'multiple': '0',
              'maxchoices': '1',
              'voterscount': '640',
              'visiblepoll': '1',
              'allowvote': '1',
              'remaintime': ['1', '0', '19', '40'],
            },
          },
        };

        final poll = ApiService.parsePoll(json);
        expect(poll, isNotNull);
        expect(poll!.options.single.id, '82378');
        expect(poll.votersCount, 640);
      });

      test('returns null for normal thread', () {
        final json = {
          'Variables': {
            'thread': {'special': '0'},
          },
        };
        expect(ApiService.parsePoll(json), isNull);
      });

      test('returns null when special_poll is missing', () {
        final json = {
          'Variables': {
            'thread': {'special': '1'},
          },
        };
        expect(ApiService.parsePoll(json), isNull);
      });
    });

    group('parsePollVoteResponse', () {
      test('returns null on redirect success XML', () {
        expect(
          ApiService.parsePollVoteResponse(
            "<?xml version=\"1.0\"?><root><![CDATA[<script>window.location.href='forum.php?mod=viewthread&tid=2285124';</script>]]></root>",
          ),
          isNull,
        );
      });

      test('returns null on success handler', () {
        expect(
          ApiService.parsePollVoteResponse(
            "succeedhandle_pollvote('tid_1', '投票成功');",
          ),
          isNull,
        );
      });

      test('returns error message on error handler', () {
        expect(
          ApiService.parsePollVoteResponse(
            "errorhandle_pollvote('已经投过票了', '');",
          ),
          '已经投过票了',
        );
      });

      test('returns error message on empty body', () {
        expect(
          ApiService.parsePollVoteResponse(''),
          contains('无响应'),
        );
      });
    });

    group('parseForumList', () {
      test('parses forum list from JSON', () {
        final json = {
          'Variables': {
            'catlist': [
              {
                'fid': '4',
                'name': '技术讨论',
                'forums': ['4'],
              }
            ],
            'forumlist': [
              {
                'fid': '4',
                'name': '技术讨论',
                'description': 'Tech discussion',
                'threads': '1000',
                'posts': '5000',
              }
            ],
          },
        };
        final forums = ApiService.parseForumList(json);
        expect(forums.length, 1);
        expect(forums[0].fid, '4');
        expect(forums[0].name, '技术讨论');
        expect(forums[0].threads, 1000);
        expect(forums[0].posts, 5000);
      });

      test('parses multiple forums', () {
        final json = {
          'Variables': {
            'catlist': [
              {
                'fid': '1',
                'name': 'Category 1',
                'forums': ['1', '2'],
              }
            ],
            'forumlist': [
              {
                'fid': '1',
                'name': 'Forum 1',
                'description': 'Desc 1',
                'threads': '100',
                'posts': '500',
              },
              {
                'fid': '2',
                'name': 'Forum 2',
                'description': 'Desc 2',
                'threads': '200',
                'posts': '1000',
              },
            ],
          },
        };
        final forums = ApiService.parseForumList(json);
        expect(forums.length, 1);
        expect(forums[0].subforums.length, 2);
        expect(forums[0].subforums[0].fid, '1');
        expect(forums[0].subforums[1].fid, '2');
      });

      test('returns empty list when forumlist is missing', () {
        final json = {'Variables': <String, dynamic>{}};
        final forums = ApiService.parseForumList(json);
        expect(forums, isEmpty);
      });

      test('returns empty list when Variables is missing', () {
        final json = <String, dynamic>{};
        final forums = ApiService.parseForumList(json);
        expect(forums, isEmpty);
      });
    });

    group('parseReplyResponse', () {
      test('returns null on success', () {
        const xml = "<root><![CDATA[<script>succeedhandle_reply('redirect.php?mod=redirect&goto=findpost&pid=123&ptid=456', '回复发布成功', {fid:'4',tid:'456',pid:'123',from:'1',sechash:'abc'});</script>]]></root>";
        expect(ApiService.parseReplyResponse(xml), isNull);
      });

      test('returns error message from errorhandle_reply', () {
        const xml = "<root><![CDATA[<script>errorhandle_reply('内容过长', 'error');</script>]]></root>";
        expect(ApiService.parseReplyResponse(xml), equals('内容过长'));
      });

      test('returns second arg when first is empty in errorhandle', () {
        const xml = "<root><![CDATA[<script>errorhandle_reply('', '操作失败');</script>]]></root>";
        expect(ApiService.parseReplyResponse(xml), equals('操作失败'));
      });

      test('returns message from alert', () {
        const xml = "<root><![CDATA[<script>alert('您没有权限回复');</script>]]></root>";
        expect(ApiService.parseReplyResponse(xml), equals('您没有权限回复'));
      });

      test('returns fallback on unknown response', () {
        const xml = '<root><![CDATA[<p>unexpected</p>]]></root>';
        expect(ApiService.parseReplyResponse(xml), equals('服务器返回未知响应'));
      });

      test('returns fallback on empty string', () {
        expect(ApiService.parseReplyResponse(''), equals('服务器返回未知响应'));
      });
    });

    group('ServerMaintenanceException', () {
      test('ensureJson throws on HTML response', () {
        const html = '<!DOCTYPE html><html><body>'
            '<div id="messagetext" class="alert_error"><p>姨妈一会，太卡了</p></div>'
            '</body></html>';
        expect(
          () => ApiService.ensureJson(html),
          throwsA(isA<ServerMaintenanceException>()),
        );
      });

      test('ensureJson extracts maintenance message from HTML', () {
        const html = '<!DOCTYPE html><html><body>'
            '<div id="messagetext" class="alert_error"><p>姨妈一会，太卡了</p></div>'
            '</body></html>';
        try {
          ApiService.ensureJson(html);
          fail('Expected ServerMaintenanceException');
        } catch (e) {
          expect(e, isA<ServerMaintenanceException>());
          expect((e as ServerMaintenanceException).message, '姨妈一会，太卡了');
        }
      });

      test('ensureJson falls back to default message when no messagetext div', () {
        const html = '<!DOCTYPE html><html><body><p>Something else</p></body></html>';
        try {
          ApiService.ensureJson(html);
          fail('Expected ServerMaintenanceException');
        } catch (e) {
          expect(e, isA<ServerMaintenanceException>());
          expect((e as ServerMaintenanceException).message, '服务器维护中，请稍后再试');
        }
      });

      test('ensureJson parses valid JSON string', () {
        const json = '{"Variables": {}}';
        final result = ApiService.ensureJson(json);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('ensureJson accepts Map directly', () {
        final map = <String, dynamic>{'Variables': <String, dynamic>{}};
        final result = ApiService.ensureJson(map);
        expect(result, map);
      });

      test('extractMaintenanceMessage extracts message from real S1 HTML', () {
        const html = '<div id="messagetext" class="alert_error">\n'
            '<p>姨妈一会，太卡了</p>\n'
            '<script type="text/javascript">';
        expect(ApiService.extractMaintenanceMessage(html), '姨妈一会，太卡了');
      });

      test('extractMaintenanceMessage returns fallback for empty HTML', () {
        expect(
          ApiService.extractMaintenanceMessage('<html></html>'),
          '服务器维护中，请稍后再试',
        );
      });
    });
  });
}
