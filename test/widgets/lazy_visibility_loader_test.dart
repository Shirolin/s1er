import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/lazy_visibility_loader.dart';

void main() {
  testWidgets('triggers when an initially offscreen child scrolls into view',
      (tester) async {
    var visibleCount = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: ListView(
            controller: controller,
            scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
            children: [
              const SizedBox(height: 1200),
              LazyVisibilityLoader(
                onVisible: () => visibleCount++,
                child: const SizedBox(height: 96),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(visibleCount, 0);

    controller.jumpTo(700);
    await tester.pump();

    expect(controller.offset, 700);
    expect(visibleCount, 1);
  });
}
