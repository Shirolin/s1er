import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
