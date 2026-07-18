import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/server_blacklist.dart';

void main() {
  test('parses users and maximum page from S1 blacklist html', () {
    const html = '''
      <ul id="friend_ul">
        <li><h4><a href="home.php?mod=space&uid=12">甲</a></h4></li>
        <li><h4><a href="home.php?mod=space&uid=34">乙</a></h4></li>
        <li><h4><a href="home.php?mod=space&uid=12">重复</a></h4></li>
      </ul>
      <div class="pg"><label><input value="1"><span>( 1 / 5 )</span></label></div>
    ''';

    final result = ServerBlacklistPage.fromHtml(html, page: 1);

    expect(result.items.map((item) => item.uid), ['12', '34']);
    expect(result.items.first.username, '甲');
    expect(result.totalPages, 5);
  });

  test('empty or malformed entries do not become users', () {
    final result = ServerBlacklistPage.fromHtml(
      '<ul id="friend_ul"><li><a href="foo">无 UID</a></li></ul>',
      page: 3,
    );
    expect(result.items, isEmpty);
    expect(result.totalPages, 3);
  });

  test('rejects unexpected html without blacklist container', () {
    expect(
      () => ServerBlacklistPage.fromHtml('<main>错误页面</main>', page: 1),
      throwsA(isA<FormatException>()),
    );
  });
}
