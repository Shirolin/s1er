import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/api_config.dart';

void main() {
  test('forumReplyReferer matches Discuz mobile reply pattern', () {
    final referer = ApiConfig.forumReplyReferer(
      fid: '4',
      tid: '2254107',
      reppost: '123',
    );

    expect(referer, contains('forum.php'));
    expect(referer, contains('mod=post'));
    expect(referer, contains('action=reply'));
    expect(referer, contains('fid=4'));
    expect(referer, contains('tid=2254107'));
    expect(referer, contains('reppost=123'));
    expect(referer, contains('mobile=2'));
    expect(referer, contains('handlekey=postform'));
  });

  test('searchForumUrl / searchUserUrl match Discuz search.php', () {
    expect(
      ApiConfig.searchForumUrl(),
      'https://stage1st.com/2b/search.php?searchsubmit=yes&mod=forum',
    );
    expect(
      ApiConfig.searchForumUrl(page: 2),
      contains('mod=forum&page=2'),
    );
    expect(
      ApiConfig.searchUserUrl(),
      'https://stage1st.com/2b/search.php?searchsubmit=yes&mod=user',
    );
  });

  test('browser URLs retain the current page and subpage', () {
    expect(
      ApiConfig.threadBrowserUrl(tid: '2254107', page: 3),
      'https://stage1st.com/2b/thread-2254107-3-1.html',
    );
    expect(
      ApiConfig.forumBrowserUrl(fid: '4', page: 2),
      'https://stage1st.com/2b/forum-4-2.html',
    );

    final pm = Uri.parse(
      ApiConfig.pmConversationBrowserUrl(touid: '42', page: 4),
    );
    expect(pm.queryParameters, containsPair('touid', '42'));
    expect(pm.queryParameters, containsPair('page', '4'));

    final favorites = Uri.parse(
      ApiConfig.favoriteBrowserUrl(uid: '7', type: 'thread', page: 5),
    );
    expect(favorites.queryParameters, containsPair('uid', '7'));
    expect(favorites.queryParameters, containsPair('type', 'thread'));
    expect(favorites.queryParameters, containsPair('page', '5'));

    final space = Uri.parse(
      ApiConfig.userSpaceBrowserUrl(uid: '9', type: 'reply', page: 6),
    );
    expect(space.queryParameters, containsPair('do', 'thread'));
    expect(space.queryParameters, containsPair('type', 'reply'));
    expect(space.queryParameters, containsPair('page', '6'));
  });

  test('browser URL helpers preserve category-specific query parameters', () {
    final allFavorites = Uri.parse(
      ApiConfig.favoriteBrowserUrl(page: 1),
    );
    expect(allFavorites.queryParameters.containsKey('type'), isFalse);
    expect(allFavorites.queryParameters, containsPair('mobile', '2'));

    final notices = Uri.parse(
      ApiConfig.messagesBrowserUrl(
        isNotice: true,
        noticeFeed: 'system',
        page: 3,
      ),
    );
    expect(notices.queryParameters, containsPair('do', 'notice'));
    expect(notices.queryParameters, containsPair('view', 'system'));
    expect(notices.queryParameters, containsPair('page', '3'));

    final messages = Uri.parse(
      ApiConfig.messagesBrowserUrl(isNotice: false, page: 2),
    );
    expect(messages.queryParameters, containsPair('do', 'pm'));
    expect(messages.queryParameters, containsPair('filter', 'privatepm'));
    expect(messages.queryParameters, containsPair('page', '2'));
  });
}
