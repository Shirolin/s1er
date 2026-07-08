import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/screens/profile_screen.dart';
import 'package:s1_app/providers/settings_provider.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('should display settings cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // 验证设置卡片存在
      expect(find.text('主题设置'), findsOneWidget);
      expect(find.text('显示设置'), findsOneWidget);
    });
  });
}
