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
  });
}
