import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/compose_bbcode_toolbar.dart';

import '../helpers/test_theme.dart';

Widget _toolbar({
  bool busy = false,
  void Function(String, String)? onWrap,
  VoidCallback? onInsertUrl,
  ValueChanged<String>? onWrapColor,
  VoidCallback? onInsertCreditHide,
}) {
  return wrapWithAppTheme(
    Scaffold(
      body: ComposeBbcodeToolbar(
        busy: busy,
        onWrap: onWrap ?? (_, __) {},
        onInsertUrl: onInsertUrl ?? () {},
        onWrapColor: onWrapColor ?? (_) {},
        onInsertCreditHide: onInsertCreditHide ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('ComposeBbcodeToolbar bold invokes onWrap with [b]',
      (tester) async {
    String? open;
    String? close;
    await tester.pumpWidget(
      _toolbar(
        onWrap: (o, c) {
          open = o;
          close = c;
        },
      ),
    );

    await tester.tap(find.byTooltip('加粗'));
    await tester.pump();
    expect(open, '[b]');
    expect(close, '[/b]');
  });

  testWidgets('ComposeBbcodeToolbar underline invokes onWrap with [u]',
      (tester) async {
    String? open;
    String? close;
    await tester.pumpWidget(
      _toolbar(
        onWrap: (o, c) {
          open = o;
          close = c;
        },
      ),
    );

    await tester.tap(find.byTooltip('下划线'));
    await tester.pump();
    expect(open, '[u]');
    expect(close, '[/u]');
  });

  testWidgets('ComposeBbcodeToolbar link invokes onInsertUrl', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _toolbar(onInsertUrl: () => called = true),
    );

    await tester.tap(find.byTooltip('链接'));
    await tester.pump();
    expect(called, isTrue);
  });

  testWidgets('ComposeBbcodeToolbar color menu selects preset hex',
      (tester) async {
    String? selected;
    await tester.pumpWidget(
      _toolbar(onWrapColor: (hex) => selected = hex),
    );

    await tester.tap(find.byTooltip('文字颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#FF0000'));
    await tester.pumpAndSettle();
    expect(selected, '#FF0000');
  });

  testWidgets('ComposeBbcodeToolbar credit hide invokes callback',
      (tester) async {
    var called = false;
    await tester.pumpWidget(
      _toolbar(onInsertCreditHide: () => called = true),
    );

    await tester.tap(find.byTooltip('积分隐藏'));
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
            onWrapColor: (_) {},
            onInsertCreditHide: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('加粗'));
    await tester.pump();
    expect(wrapCalled, isFalse);
  });
}
