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

/// 注入系统底栏 padding，模拟「内容画到导航栏之后」（Android 15+ edge-to-edge）。
Widget _withBottomInset(Widget child, double bottom) {
  return MediaQuery(
    data: MediaQueryData(padding: EdgeInsets.only(bottom: bottom)),
    child: child,
  );
}

void main() {
  group('S1BottomOverlayStyle 拥有导航栏区域（bottom > 0）', () {
    testWidgets('浅色主题请求深色导航栏图标', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          _withBottomInset(const S1BottomOverlayStyle(child: SizedBox()), 48),
        ),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarIconBrightness, Brightness.dark);
    });

    testWidgets('深色主题请求浅色导航栏图标', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          _withBottomInset(const S1BottomOverlayStyle(child: SizedBox()), 48),
          dark: true,
        ),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('关闭系统 contrast scrim，底色交给自绘色带', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          _withBottomInset(const S1BottomOverlayStyle(child: SizedBox()), 48),
        ),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarContrastEnforced, isFalse);
      // 颜色留给系统默认：API 35+ 引擎忽略它，旧版本仍需系统不透明底。
      expect(value.systemNavigationBarColor, isNull);
    });
  });

  group('S1BottomOverlayStyle 未拥有导航栏区域（bottom == 0）', () {
    testWidgets('浅色主题下全部保持系统默认（不改图标亮度）', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(const S1BottomOverlayStyle(child: SizedBox())),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarIconBrightness, isNull);
      expect(value.systemNavigationBarContrastEnforced, isNull);
      expect(value.systemNavigationBarColor, isNull);
    });

    testWidgets('深色主题下同样保持系统默认', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          const S1BottomOverlayStyle(child: SizedBox()),
          dark: true,
        ),
      );

      final value = _region(tester).value;
      expect(value.systemNavigationBarIconBrightness, isNull);
      expect(value.systemNavigationBarContrastEnforced, isNull);
    });
  });

  testWidgets('透传 child', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        _withBottomInset(
          const S1BottomOverlayStyle(child: Text('content')),
          48,
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
  });
}
