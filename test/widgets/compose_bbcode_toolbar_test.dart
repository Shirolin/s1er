import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/compose_bbcode_toolbar.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('ComposeBbcodeToolbar bold invokes onWrap with [b]',
      (tester) async {
    String? open;
    String? close;
    await tester.pumpWidget(
      wrapWithAppTheme(
        Scaffold(
          body: ComposeBbcodeToolbar(
            busy: false,
            onWrap: (o, c) {
              open = o;
              close = c;
            },
            onInsertUrl: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('加粗'));
    await tester.pump();
    expect(open, '[b]');
    expect(close, '[/b]');
  });

  testWidgets('ComposeBbcodeToolbar link invokes onInsertUrl', (tester) async {
    var called = false;
    await tester.pumpWidget(
      wrapWithAppTheme(
        Scaffold(
          body: ComposeBbcodeToolbar(
            busy: false,
            onWrap: (_, __) {},
            onInsertUrl: () => called = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('链接'));
    await tester.pump();
    expect(called, isTrue);
  });

  testWidgets('ComposeBbcodeToolbar disables actions when busy',
      (tester) async {
    var wrapCalled = false;
    await tester.pumpWidget(
      wrapWithAppTheme(
        Scaffold(
          body: ComposeBbcodeToolbar(
            busy: true,
            onWrap: (_, __) => wrapCalled = true,
            onInsertUrl: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('加粗'));
    await tester.pump();
    expect(wrapCalled, isFalse);
  });
}
