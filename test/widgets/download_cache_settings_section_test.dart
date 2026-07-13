import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/image_cache_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/widgets/settings/download_cache_settings_section.dart';

import '../helpers/test_theme.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    Future<int> Function(Ref ref)? cacheSize,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
          imageCacheSizeProvider.overrideWith(
            cacheSize ?? (ref) async => 1024,
          ),
        ],
        child: wrapWithAppTheme(const DownloadCacheSettingsSection()),
      ),
    );
    await tester.pump();
  }

  group('DownloadCacheSettingsSection', () {
    testWidgets('does not scan cache size before user requests it',
        (tester) async {
      await pumpSection(tester);

      expect(find.text('正在统计缓存占用…'), findsNothing);
      expect(find.text('查看占用'), findsOneWidget);
      expect(find.text('点击「查看占用」统计本地图片缓存'), findsOneWidget);
    });

    testWidgets('shows cache size after tapping 查看占用', (tester) async {
      await pumpSection(tester, cacheSize: (ref) async => 2048);

      await tester.tap(find.text('查看占用'));
      await tester.pump();
      expect(find.text('正在统计缓存占用…'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.textContaining('当前约占用'), findsOneWidget);
      expect(find.text('查看占用'), findsNothing);
    });

    testWidgets('refreshes displayed size after clear when size was requested',
        (tester) async {
      var reportedBytes = 4096;

      await pumpSection(
        tester,
        cacheSize: (ref) async => reportedBytes,
      );

      await tester.tap(find.text('查看占用'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4.0 KB'), findsOneWidget);

      reportedBytes = 0;
      final element = tester.element(find.byType(DownloadCacheSettingsSection));
      final container = ProviderScope.containerOf(element);
      container.invalidate(imageCacheSizeProvider);
      await tester.pumpAndSettle();

      expect(find.textContaining('0 B'), findsOneWidget);
    });
  });
}
