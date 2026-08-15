import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/theme/s1_reading_card_style.dart';

void main() {
  Future<BuildContext> pumpAt(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('compact + enabled is full-bleed', (tester) async {
    final context = await pumpAt(tester, size: const Size(400, 800));
    expect(S1ReadingCardStyle.isFullBleed(context, enabled: true), isTrue);
    expect(
      S1ReadingCardStyle.margin(context, enabled: true, vertical: 4),
      const EdgeInsets.symmetric(vertical: 4),
    );
    expect(
      S1ReadingCardStyle.inkBorderRadius(context, enabled: true),
      BorderRadius.zero,
    );
    final shape = S1ReadingCardStyle.shape(context, enabled: true)
        as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(shape.side, BorderSide.none);
  });

  testWidgets('compact + disabled keeps floating card', (tester) async {
    final context = await pumpAt(tester, size: const Size(400, 800));
    expect(S1ReadingCardStyle.isFullBleed(context, enabled: false), isFalse);
    expect(
      S1ReadingCardStyle.margin(context, enabled: false, vertical: 5),
      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
    expect(
      S1ReadingCardStyle.inkBorderRadius(context, enabled: false),
      S1Shape.medium,
    );
  });

  testWidgets('medium + enabled still keeps floating card', (tester) async {
    final context = await pumpAt(tester, size: const Size(800, 800));
    expect(S1ReadingCardStyle.isFullBleed(context, enabled: true), isFalse);
    expect(
      S1ReadingCardStyle.margin(context, enabled: true, vertical: 4),
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
    expect(
      S1ReadingCardStyle.inkBorderRadius(context, enabled: true),
      S1Shape.medium,
    );
  });

  testWidgets('full-bleed selected outline keeps zero radius', (tester) async {
    final context = await pumpAt(tester, size: const Size(400, 800));
    final shape = S1ReadingCardStyle.shape(
      context,
      enabled: true,
      side: const BorderSide(width: 1.5),
    ) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(shape.side.width, 1.5);
  });
}
