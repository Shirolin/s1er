import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/s1_bottom_overlay_style.dart';

import '../helpers/test_theme.dart';

AnnotatedRegion<SystemUiOverlayStyle> _region(WidgetTester tester) {
  return tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
  );
}

void main() {
  group('S1BottomOverlayStyle', () {
    testWidgets('浅色主题请求深色导航栏图标', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(const S1BottomOverlayStyle(child: SizedBox())),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarIconBrightness, Brightness.dark);
    });

    testWidgets('深色主题请求浅色导航栏图标', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          const S1BottomOverlayStyle(child: SizedBox()),
          dark: true,
        ),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('关闭系统 contrast scrim，底色交给自绘色带', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(const S1BottomOverlayStyle(child: SizedBox())),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarContrastEnforced, isFalse);
      expect(value.systemNavigationBarColor, Colors.transparent);
    });

    testWidgets('透传 child', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          const S1BottomOverlayStyle(child: Text('content')),
        ),
      );

      expect(find.text('content'), findsOneWidget);
    });
  });
}
