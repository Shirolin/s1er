import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1_app/providers/talker_provider.dart';
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
    testWidgets('should display theme settings card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
              ),
            ),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('主题设置'), findsOneWidget);
      expect(find.text('主题外观'), findsOneWidget);
      expect(find.text('主题配色'), findsOneWidget);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);
    });

    testWidgets('should display display settings card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
              ),
            ),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('显示设置'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('显示设置'), findsOneWidget);
      expect(find.text('显示图片'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
    });

    testWidgets('should display color labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
              ),
            ),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('蓝'), findsOneWidget);
      expect(find.text('紫'), findsOneWidget);
      expect(find.text('绿'), findsOneWidget);
      expect(find.text('黛'), findsOneWidget);
      expect(find.text('橙'), findsOneWidget);
    });
  });
}
