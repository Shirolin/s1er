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
}
