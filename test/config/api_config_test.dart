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
}
