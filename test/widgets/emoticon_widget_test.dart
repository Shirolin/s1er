import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/emoticon_catalog.dart';
import 'package:s1er/widgets/emoticon_widget.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('emoticon images are decorative for screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();
    final item = EmoticonCatalog.findByCode('f:001')!;

    await tester.pumpWidget(
      wrapWithAppTheme(
        Center(child: EmoticonImage(item: item)),
      ),
    );
    await tester.pump();

    // 表情跟在正文里；带 image 语义时整楼会被读成「图片」。
    final data =
        tester.getSemantics(find.byType(EmoticonImage)).getSemanticsData();
    expect(data.flagsCollection.isImage, isFalse);

    handle.dispose();
  });
}
