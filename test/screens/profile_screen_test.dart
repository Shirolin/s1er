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
    await Hive.openBox<Map>('reading_history');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('ProfileScreen', () {
    testWidgets('shows settings entry tile', (tester) async {
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
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题、文字大小与显示'), findsOneWidget);
      expect(find.text('主题设置'), findsNothing);
    });
  });
}
