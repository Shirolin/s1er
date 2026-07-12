import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/providers/talker_provider.dart';
import 'package:s1_app/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen displays all settings sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
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
          theme: AppTheme.lightTheme('purple'),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('主题设置'), findsOneWidget);
    expect(find.text('文字大小'), findsOneWidget);
    expect(find.text('浏览行为'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('Material You 动态取色'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text('版本'), findsOneWidget);
  });
}
