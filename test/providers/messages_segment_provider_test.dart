import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/notice_item.dart';
import 'package:s1er/providers/messages_segment_provider.dart';

void main() {
  test('messagesBrowserUrl returns pm page for segment 0', () {
    final url = messagesBrowserUrl(0);
    expect(url, contains('do=pm'));
    expect(url, contains('filter=privatepm'));
  });

  test('messagesBrowserUrl returns notice page for segment 1', () {
    final url = messagesBrowserUrl(1);
    expect(url, contains('do=notice'));
    expect(url, contains('view=mypost'));
    expect(url, contains('isread=1'));
  });

  test('messagesBrowserUrl follows selected system notice feed', () {
    final url = messagesBrowserUrl(1, noticeFeed: NoticeFeed.system);
    expect(url, contains('view=system'));
  });

  test('messagesBrowserUrl retains the current page', () {
    expect(messagesBrowserUrl(0, page: 3), contains('page=3'));
    expect(
      messagesBrowserUrl(1, noticeFeed: NoticeFeed.system, page: 4),
      contains('page=4'),
    );
  });
}
