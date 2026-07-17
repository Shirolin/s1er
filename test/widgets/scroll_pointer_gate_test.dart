import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/scroll_pointer_gate.dart';

void main() {
  testWidgets('ScrollPointerGateHost ignores pointers while scrolling',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollPointerGateHost(
            idleDelay: const Duration(milliseconds: 50),
            child: ListView(
              children: [
                const SizedBox(height: 200),
                ScrollAwareIgnorePointer(
                  child: ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('tap-target'),
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap-target'));
    expect(taps, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.text('tap-target'), warnIfMissed: false);
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('tap-target'));
    expect(taps, 2);
  });
}
