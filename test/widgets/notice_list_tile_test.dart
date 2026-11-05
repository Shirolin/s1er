import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/notice_item.dart';
import 'package:s1er/widgets/notice_list_tile.dart';

import '../helpers/test_theme.dart';

NoticeItem _item(String author, String summary) => NoticeItem(
      id: '1',
      authorUid: '2',
      authorName: author,
      summary: summary,
      dateline: 0,
      tid: '3',
    );

void main() {
  test('summaryWithoutAuthor 去掉正文开头重复的作者名', () {
    expect(
      NoticeListTile.summaryWithoutAuthor(
        '無始無終 回复了您的帖子 [S1er] 又又一个第三方 查看',
        '無始無終',
      ),
      '回复了您的帖子 [S1er] 又又一个第三方 查看',
    );
  });

  test('summaryWithoutAuthor 不误伤不以作者名开头的正文', () {
    const summary = '您的账号已被标记为异常登录';
    expect(
      NoticeListTile.summaryWithoutAuthor(summary, '系统通知'),
      summary,
    );
    expect(NoticeListTile.summaryWithoutAuthor(summary, ''), summary);
  });

  test('displaySummary 同时去掉作者名与结尾的「查看」链接文字', () {
    expect(
      NoticeListTile.displaySummary('無始無終 回复了您的帖子 [S1er] 查看', '無始無終'),
      '回复了您的帖子 [S1er]',
    );
  });

  testWidgets('列表行不再重复显示作者名与「查看」', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        NoticeListTile(
          item: _item('無始無終', '無始無終 回复了您的帖子 [S1er] 查看'),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('無始無終'), findsOneWidget);
    expect(find.text('回复了您的帖子 [S1er]'), findsOneWidget);
  });
}
