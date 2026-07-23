import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/s1_snack_bar.dart';

import '../helpers/test_theme.dart';

void main() {
  Widget buildTestApp(Widget child, {Size size = const Size(400, 800)}) {
    return wrapWithAppTheme(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  testWidgets('S1SnackBar.show displays info icon and text', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => S1SnackBar.show(context, message: '提示信息'),
              child: const Text('Show'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('提示信息'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('S1SnackBar.success displays check icon and text',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => S1SnackBar.success(context, message: '操作成功'),
              child: const Text('Success'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Success'));
    await tester.pump();

    expect(find.text('操作成功'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('S1SnackBar.error displays error icon and text', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => S1SnackBar.error(context, message: '操作失败'),
              child: const Text('Error'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Error'));
    await tester.pump();

    expect(find.text('操作失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('S1SnackBar flushes previous snackbar on new show call',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () => S1SnackBar.show(context, message: '消息 1'),
                  child: const Text('Msg1'),
                ),
                ElevatedButton(
                  onPressed: () => S1SnackBar.show(context, message: '消息 2'),
                  child: const Text('Msg2'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Msg1'));
    await tester.pump();
    expect(find.text('消息 1'), findsOneWidget);

    await tester.tap(find.text('Msg2'));
    await tester.pump();
    expect(find.text('消息 2'), findsOneWidget);
  });

  testWidgets('S1SnackBar sets maxWidth 400 on wide screens (> 600)',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => S1SnackBar.show(context, message: '宽屏消息'),
              child: const Text('WideShow'),
            );
          },
        ),
        size: const Size(1000, 800),
      ),
    );

    await tester.tap(find.text('WideShow'));
    await tester.pump();

    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);
    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.width, 400.0);
  });
}
