import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/rate_form.dart';
import 'package:s1er/services/api_service.dart';

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

      test('supports an explicit API version', () {
        final url = ApiService.buildApiUrl(
          module: 'mynotelist',
          version: '3',
        );
        expect(url, contains('version=3'));
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

      test('builds separate forum type filter parameters', () {
        final url = Uri.parse(
          ApiService.buildThreadListUrl('4', page: 2, typeId: '8'),
        );

        expect(url.queryParameters['fid'], '4');
        expect(url.queryParameters['page'], '2');
        expect(url.queryParameters['filter'], 'typeid');
        expect(url.queryParameters['typeid'], '8');
        expect(url.queryParameters['tpp'], '50');
      });

      test('omits type filter for the full forum list', () {
        final url = Uri.parse(ApiService.buildThreadListUrl('4'));

        expect(url.queryParameters.containsKey('filter'), isFalse);
        expect(url.queryParameters.containsKey('typeid'), isFalse);
        expect(url.queryParameters['tpp'], '50');
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

      test('uses filtered threadcount before forum total for pagination', () {
        final pages = ApiService.parseThreadListTotalPages(
          {
            'Variables': {
              'threadcount': '72',
              'tpp': '50',
              'forum': {'threads': '9999'},
            },
          },
          currentPage: 1,
          itemCount: 50,
          isFiltered: true,
        );

        expect(pages, 2);
      });

      test('infers a next filtered page when count is absent', () {
        final pages = ApiService.parseThreadListTotalPages(
          {
            'Variables': {
              'forum': {'threads': '9999'},
            },
          },
          currentPage: 2,
          itemCount: 50,
          isFiltered: true,
        );

        expect(pages, 3);
      });
    });

    group('parseForumDisplayName', () {
      test('returns forum name from Variables.forum', () {
        final name = ApiService.parseForumDisplayName({
          'Variables': {
            'forum': {'name': '  游戏论坛  '},
          },
        });
        expect(name, '游戏论坛');
      });

      test('returns null when forum name is missing', () {
        expect(ApiService.parseForumDisplayName({}), isNull);
        expect(
          ApiService.parseForumDisplayName({
            'Variables': {'forum': <String, dynamic>{}},
          }),
          isNull,
        );
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

    group('parseCommentCount', () {
      test('parses comment count map from viewthread JSON', () {
        final json = {
          'Variables': {
            'commentcount': {
              '100': '2',
              '200': 0,
            },
          },
        };

        expect(ApiService.parseCommentCount(json), {'100': 2, '200': 0});
      });

      test('returns empty map when commentcount is missing', () {
        final json = {'Variables': <String, dynamic>{}};
        expect(ApiService.parseCommentCount(json), isEmpty);
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

    group('parseRateFormResponse', () {
      const formHtml = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[<form id="rateform">
<input type="hidden" name="formhash" value="2867b07a" />
<select id="rate1"><option>0</option><option>+2</option><option>+1</option><option>-1</option><option>-2</option></select>
<select id="reason"><option value=""></option><option value="好评加鹅">好评加鹅</option><option value="欢乐多">欢乐多</option><option value="思路广">思路广</option></select>
</form>]]></root>''';

      test('parses score and reason presets from rate form', () {
        final options = ApiService.parseRateFormResponse(formHtml);

        expect(options.hasError, isFalse);
        expect(options.scoreOptions, ['0', '+2', '+1', '-1', '-2']);
        expect(options.reasonPresets, ['', '好评加鹅', '欢乐多', '思路广']);
      });

      test('parses rich rate form fields from Discuz html', () {
        const richFormHtml = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[
<form id="rateform">
  <input type="hidden" name="formhash" value="2867b07a" />
  <input type="hidden" name="tid" value="2285380" />
  <input type="hidden" name="pid" value="67953733" />
  <input type="hidden" name="referer" value="forum.php?mod=viewthread&amp;tid=2285380" />
  <input type="hidden" name="handlekey" value="rate" />
  <table class="dt mbm"><tbody>
    <tr><td>项目</td><td>分值</td><td>范围</td><td>今日剩余</td></tr>
    <tr><td>战斗力</td><td></td><td>-2 ~ +2</td><td>+5</td></tr>
  </tbody></table>
  <ul id="reasonselect">
    <li>好评加鹅</li>
    <li>欢乐多</li>
  </ul>
  <input type="checkbox" id="sendreasonpm" checked="checked" disabled="disabled" />
</form>
]]></root>''';

        final options = ApiService.parseRateFormResponse(richFormHtml);

        expect(options.formHash, '2867b07a');
        expect(options.tid, '2285380');
        expect(options.pid, '67953733');
        expect(options.referer, 'forum.php?mod=viewthread&tid=2285380');
        expect(options.handleKey, 'rate');
        expect(options.minScore, -2);
        expect(options.maxScore, 2);
        expect(options.totalScore, 5);
        expect(options.buildScoreOptions(), ['+2', '+1', '-1', '-2']);
        expect(options.preferredDefaultScore, '+1');
        expect(options.reasonPresets, ['好评加鹅', '欢乐多']);
        expect(options.notifyAuthorDefault, isTrue);
        expect(options.notifyAuthorDisabled, isTrue);
      });

      test('returns error for self-rate message', () {
        const errorHtml = '''
<root><![CDATA[<div class="tip"><dt id="messagetext">
<p>抱歉，您不能给自己发表的帖子评分</p>
</dt></div>]]></root>''';

        final options = ApiService.parseRateFormResponse(errorHtml);

        expect(options.hasError, isTrue);
        expect(options.error, contains('不能给自己'));
      });

      test('falls back to defaults on empty body', () {
        final options = ApiService.parseRateFormResponse('');

        expect(options.hasError, isFalse);
        expect(options.scoreOptions, RateFormOptions.defaultScoreOptions);
        expect(options.reasonPresets, RateFormOptions.defaultReasonPresets);
      });
    });

    group('parseRateSubmitResponse', () {
      test('returns null on redirect success XML', () {
        expect(
          ApiService.parseRateSubmitResponse(
            "<?xml version=\"1.0\"?><root><![CDATA[<script>window.location.href='forum.php?mod=viewthread&tid=2285380';</script>]]></root>",
          ),
          isNull,
        );
      });

      test('returns null on success handler', () {
        expect(
          ApiService.parseRateSubmitResponse(
            "succeedhandle_rate('pid_1', '评分成功');",
          ),
          isNull,
        );
      });

      test('returns error message on error handler', () {
        expect(
          ApiService.parseRateSubmitResponse(
            "errorhandle_rate('已经评过分了', '');",
          ),
          '已经评过分了',
        );
      });

      test('returns error message on messagetext', () {
        expect(
          ApiService.parseRateSubmitResponse(
            '<dt id="messagetext"><p>抱歉，您不能给自己发表的帖子评分</p></dt>',
          ),
          contains('不能给自己'),
        );
      });

      test('returns error message on empty body', () {
        expect(
          ApiService.parseRateSubmitResponse(''),
          contains('无响应'),
        );
      });
    });

    group('parseForumList', () {
      test(
        'parses guest forumindex data even when response also has to_login message',
        () {
          final json = {
            'Message': {'messageval': 'to_login'},
            'Variables': {
              'catlist': [
                {
                  'fid': '1',
                  'name': '主论坛',
                  'forums': ['4'],
                },
              ],
              'forumlist': [
                {
                  'fid': '4',
                  'name': '游戏论坛',
                  'description': '游戏文化，原创，新闻',
                  'threads': '203673',
                  'posts': '8788642',
                  'todayposts': '835',
                },
              ],
            },
          };

          final forums = ApiService.parseForumList(json);

          expect(forums, hasLength(1));
          expect(forums.single.name, '主论坛');
          expect(forums.single.subforums, hasLength(1));
          expect(forums.single.subforums.single.name, '游戏论坛');
        },
      );

      test('parses Discuz object-shaped guest forumindex lists', () {
        final json = {
          'Message': {'messageval': 'to_login'},
          'Variables': {
            'catlist': {
              '1': {
                'fid': '1',
                'name': '主论坛',
                'forums': {
                  '0': '4',
                },
              },
            },
            'forumlist': {
              '4': {
                'fid': '4',
                'name': '游戏论坛',
                'description': '游戏文化，原创，新闻',
                'threads': '203673',
                'posts': '8788642',
                'todayposts': '835',
              },
            },
          },
        };

        final forums = ApiService.parseForumList(json);

        expect(forums, hasLength(1));
        expect(forums.single.name, '主论坛');
        expect(forums.single.subforums.single.fid, '4');
      });

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
      test('returns success result with pid and tid', () {
        const xml =
            "<root><![CDATA[<script>succeedhandle_reply('redirect.php?mod=redirect&goto=findpost&pid=123&ptid=456', '回复发布成功', {fid:'4',tid:'456',pid:'123',from:'1',sechash:'abc'});</script>]]></root>";
        final result = ApiService.parseReplyResponse(xml);
        expect(result.isSuccess, isTrue);
        expect(result.pid, '123');
        expect(result.tid, '456');
        expect(result.error, isNull);
      });

      test('returns success result from Discuz postform handler', () {
        const xml = '''<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[<div class="tip">
<dt id="messagetext">
<p>非常感谢，回复发布成功，现在将转入主题页，请稍候……<br /><a href="forum-4-1.html">[ 点击这里转入主题列表 ]</a><script type="text/javascript" reload="1">if(typeof succeedhandle_postform=='function') {succeedhandle_postform('forum.php?mod=viewthread&tid=2042115&pid=69904041&page=187&extra=&mobile=2#pid69904041', '非常感谢，回复发布成功，现在将转入主题页，请稍候……[ 点击这里转入主题列表 ]', {'fid':'4','tid':'2042115','pid':'69904041','from':'','sechash':''});}</script></p>
</dt>
</div>
]]></root>''';

        final result = ApiService.parseReplyResponse(xml);

        expect(result.isSuccess, isTrue);
        expect(result.pid, '69904041');
        expect(result.tid, '2042115');
        expect(result.error, isNull);
      });

      test('returns error message from errorhandle_reply', () {
        const xml =
            "<root><![CDATA[<script>errorhandle_reply('内容过长', 'error');</script>]]></root>";
        final result = ApiService.parseReplyResponse(xml);
        expect(result.isSuccess, isFalse);
        expect(result.error, '内容过长');
      });

      test('returns second arg when first is empty in errorhandle', () {
        const xml =
            "<root><![CDATA[<script>errorhandle_reply('', '操作失败');</script>]]></root>";
        final result = ApiService.parseReplyResponse(xml);
        expect(result.error, '操作失败');
      });

      test('returns message from alert', () {
        const xml =
            "<root><![CDATA[<script>alert('您没有权限回复');</script>]]></root>";
        final result = ApiService.parseReplyResponse(xml);
        expect(result.error, '您没有权限回复');
      });

      test('returns message from errorhandle_postform', () {
        const xml =
            "<root><![CDATA[<script>errorhandle_postform('抱歉，您的请求来路不正确或表单验证串不符，无法提交', {});</script>]]></root>";
        final result = ApiService.parseReplyResponse(xml);
        expect(result.error, '抱歉，您的请求来路不正确或表单验证串不符，无法提交');
      });

      test('returns message from messagetext html', () {
        const xml = '''<root><![CDATA[<div class="tip">
<dt id="messagetext">
<p>抱歉，您的请求来路不正确或表单验证串不符，无法提交</p>
</dt>
</div>]]></root>''';
        final result = ApiService.parseReplyResponse(xml);
        expect(result.error, '抱歉，您的请求来路不正确或表单验证串不符，无法提交');
      });

      test('returns fallback on unknown response', () {
        const xml = '<root><![CDATA[<p>unexpected</p>]]></root>';
        final result = ApiService.parseReplyResponse(xml);
        expect(result.error, '服务器返回未知响应');
      });

      test('returns fallback on empty string', () {
        final result = ApiService.parseReplyResponse('');
        expect(result.error, '服务器返回未知响应');
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

      test('ensureJson falls back to default message when no messagetext div',
          () {
        const html =
            '<!DOCTYPE html><html><body><p>Something else</p></body></html>';
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

    group('pageFromFindpostLocation', () {
      test('maps Discuz page=0 redirect to page 1', () {
        expect(
          ApiService.pageFromFindpostLocation(
            'forum.php?mod=viewthread&tid=2187698&page=0#pid52629852',
            expectedTid: '2187698',
          ),
          1,
        );
      });

      test('keeps explicit page >= 1', () {
        expect(
          ApiService.pageFromFindpostLocation(
            'forum.php?mod=viewthread&tid=2274556&page=3261#pid60800000',
            expectedTid: '2274556',
          ),
          3261,
        );
      });

      test('omitted page on same-tid viewthread is page 1', () {
        expect(
          ApiService.pageFromFindpostLocation(
            'forum.php?mod=viewthread&tid=100',
            expectedTid: '100',
          ),
          1,
        );
      });

      test('reads page from pseudo-static path', () {
        expect(
          ApiService.pageFromFindpostLocation(
            'https://stage1st.com/2b/thread-100-3-1.html',
            expectedTid: '100',
          ),
          3,
        );
      });

      test('returns null for unrelated location', () {
        expect(
          ApiService.pageFromFindpostLocation(
            'https://example.com/other',
            expectedTid: '100',
          ),
          isNull,
        );
      });

      test('mobile viewthread without page is page 1', () {
        expect(
          ApiService.pageFromFindpostLocation(
            'forum.php?mod=viewthread&tid=2017380&mobile=2',
            expectedTid: '2017380',
          ),
          1,
        );
      });
    });

    group('pageFromViewthreadHtml', () {
      test('reads current page from div.pg strong', () {
        const html = '''
<div id="pgt" class="pgs mbm cl">
<div class="pg"><strong>3</strong><a href="thread-1-4-1.html">4</a></div>
</div>
<p>正文里也有 <strong>登录</strong> 不应干扰</p>
''';
        expect(ApiService.pageFromViewthreadHtml(html), 3);
      });

      test('returns null when no pagination', () {
        expect(
          ApiService.pageFromViewthreadHtml('<div id="messagetext">err</div>'),
          isNull,
        );
      });
    });

    group('parseSpaceReplyHtml', () {
      test('parses desktop ptid-then-pid links', () {
        const html = '''
<table>
<tr class="bw0_all"><td>
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=100&amp;pid=">标题A</a>
<a href="forum-4-1-1.html" class="xg1">游戏</a>
</td></tr>
<tr><td colspan="5">
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=100&amp;pid=55">回复摘要一</a>
</td></tr>
</table>
''';
        final result = ApiService.parseSpaceReplyHtmlForTest(html);
        expect(result.items, hasLength(1));
        expect(result.items.first.tid, '100');
        expect(result.items.first.pid, '55');
        expect(result.items.first.subject, '标题A');
        expect(result.items.first.replyExcerpt, '回复摘要一');
      });

      test('parses desktop pid-then-ptid links', () {
        const html = '''
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=200&amp;pid=">标题B</a>
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;pid=99&amp;ptid=200">摘要B</a>
''';
        final result = ApiService.parseSpaceReplyHtmlForTest(html);
        expect(result.items, hasLength(1));
        expect(result.items.first.tid, '200');
        expect(result.items.first.pid, '99');
        expect(result.items.first.replyExcerpt, '摘要B');
      });

      test('parses mobile threadlist with findpost anchors', () {
        const html = '''
<div class="threadlist cl">
<li class="list">
<em>手机标题</em>
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=300&amp;pid=">手机标题</a>
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;pid=42&amp;ptid=300"><blockquote>手机回复</blockquote></a>
</li>
</div>
''';
        final result = ApiService.parseSpaceReplyHtmlForTest(html);
        expect(result.items, hasLength(1));
        expect(result.items.first.tid, '300');
        expect(result.items.first.pid, '42');
        expect(result.items.first.subject, '手机标题');
        expect(result.items.first.replyExcerpt, '手机回复');
      });
    });
  });
}
