import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s1_app/screens/profile_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init(Directory.systemTemp.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('ProfileScreen', () {
    testWidgets('should display settings cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      // ThemeSettingsCard should be visible without scrolling
      expect(find.text('主题设置'), findsOneWidget);

      // Scroll down to reveal DisplaySettingsCard (ListView lazily builds children)
      await tester.scrollUntilVisible(
        find.text('显示设置'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('显示设置'), findsOneWidget);
    });
  });
}
