import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_search_query.dart';

void main() {
  test('Dio encodes srchfid and special as single-bracket array fields', () {
    final fields = const ForumSearchQuery(
      keyword: 'test',
      author: 'alice',
      specials: {1, 3},
      forumIds: {'4', '51'},
    ).toPostFields();

    final body = Transformer.urlEncodeMap(
      fields,
      ListFormat.multiCompatible,
    );

    expect(body, contains('srchfid%5B%5D=4'));
    expect(body, contains('srchfid%5B%5D=51'));
    expect(body, isNot(contains('srchfid%5B%5D%5B%5D')));
    expect(body, contains('special%5B%5D=1'));
    expect(body, contains('special%5B%5D=3'));
    expect(body, isNot(contains('special%5B%5D%5B%5D')));
  });
}
