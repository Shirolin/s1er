import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/s1_local_search_bar.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('S1LocalSearchBar calls onChanged and clear', (tester) async {
    var query = '';
    var closed = false;
    await tester.pumpWidget(
      wrapWithAppTheme(
        StatefulBuilder(
          builder: (context, setState) {
            return S1LocalSearchBar(
              hintText: '搜索本页主题 / 作者',
              query: query,
              matchCount: query.trim().isEmpty ? null : 3,
              onChanged: (q) => setState(() => query = q),
              onClose: () => closed = true,
            );
          },
        ),
      ),
    );

    expect(find.text('搜索本页主题 / 作者'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'hello');
    await tester.pump();
    expect(query, 'hello');
    expect(find.text('3 条'), findsOneWidget);
    expect(find.byTooltip('清除'), findsOneWidget);

    await tester.tap(find.byTooltip('清除'));
    await tester.pump();
    expect(query, '');
    expect(find.text('3 条'), findsNothing);

    await tester.tap(find.byTooltip('关闭本页搜索'));
    await tester.pump();
    expect(closed, isTrue);
  });
}
