import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/thread_detail_chrome_bridge.dart';

void main() {
  testWidgets('publish during build does not mark ListenableBuilder dirty',
      (tester) async {
    final bridge = ThreadDetailChromeBridge();
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            bridge.publish(
              const ThreadDetailChromeSnapshot(
                canPrevPage: true,
              ),
            );
            return ListenableBuilder(
              listenable: bridge,
              builder: (context, _) => Text(
                bridge.snapshot?.canPrevPage == true ? 'prev' : 'none',
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('prev'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
