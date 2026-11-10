import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/app_icon_catalog.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_icon_service.dart';
import 'package:s1er/widgets/settings/app_icon_picker.dart';

import '../helpers/test_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.stage1st.s1er/app_icon');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('renders black and white variants and switches selection',
      (tester) async {
    final service = AppIconService(supportedOverride: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIconServiceProvider.overrideWithValue(service),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(appIcon: 'black'),
              appIconService: service,
            ),
          ),
        ],
        child: wrapWithAppTheme(const AppIconPicker()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('黑底'), findsOneWidget);
    expect(find.text('白底'), findsOneWidget);
    expect(find.text('重启生效'), findsNothing);

    await tester.tap(find.text('白底'));
    await tester.pumpAndSettle();

    // Android test binding：确认后再切换。
    expect(find.text('更换应用图标'), findsOneWidget);
    await tester.tap(find.text('更换并关闭'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppIconPicker)),
    );
    expect(container.read(settingsProvider).appIcon, 'white');
  });

  testWidgets('窄屏下五个预览图仍为正方形（cover 不裁构图）', (tester) async {
    // 360dp 手机：五列并排时每栏可用宽 < 56，旧实现里 SizedBox 被压成 48×56，
    // BoxFit.cover 于是横向裁掉构图，深色主题图标看上去被“纵向拉长”。
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final service = AppIconService(supportedOverride: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIconServiceProvider.overrideWithValue(service),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(appIcon: 'black'),
              appIconService: service,
            ),
          ),
        ],
        // 真实位置在设置卡片内（左右有留白），五列可用宽才 < 56。
        child: wrapWithAppTheme(
          const Padding(padding: EdgeInsets.all(16), child: AppIconPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final images = find.byType(Image);
    expect(images, findsNWidgets(AppIconCatalog.variants.length));
    for (final element in images.evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(
        size.width,
        size.height,
        reason: '预览图被拉成 ${size.width}x${size.height}',
      );
      expect(size.width, lessThanOrEqualTo(56.0));
    }
  });

  testWidgets('cancel confirm keeps previous icon', (tester) async {
    final service = AppIconService(supportedOverride: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIconServiceProvider.overrideWithValue(service),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(appIcon: 'black'),
              appIconService: service,
            ),
          ),
        ],
        child: wrapWithAppTheme(const AppIconPicker()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('白底'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppIconPicker)),
    );
    expect(container.read(settingsProvider).appIcon, 'black');
  });
}
