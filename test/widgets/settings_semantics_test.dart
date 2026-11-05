import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/device_model_label_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/widgets/settings/browsing_settings_section.dart';
import 'package:s1er/widgets/settings/post_signature_settings_section.dart';

import '../helpers/test_theme.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
          deviceModelLabelProvider.overrideWith((ref) async => '测试机'),
        ],
        child: wrapWithAppTheme(child),
      ),
    );
    await tester.pump();
  }

  testWidgets('已屏蔽版块行不吞掉整个「浏览行为」分区的文本', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSection(tester, const BrowsingSettingsSection());

    final tileLabel = tester.getSemantics(find.text('已屏蔽版块')).label;
    expect(tileLabel, contains('已屏蔽版块'));
    expect(tileLabel, isNot(contains('浏览行为')));
    expect(tileLabel, isNot(contains('楼层密度')));

    // 开关仍需各自独立可读。
    expect(find.bySemanticsLabel(RegExp(r'^记录阅读历史')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^窄屏列表铺满')), findsOneWidget);

    handle.dispose();
  });

  testWidgets('自定义前缀输入框不把分区文本并进读屏标签', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSection(tester, const PostSignatureSettingsSection());

    final fieldLabel = tester.getSemantics(find.byType(TextField)).label;
    expect(fieldLabel, contains('自定义前缀'));
    expect(fieldLabel, isNot(contains('发帖小尾巴')));
    expect(fieldLabel, isNot(contains('预览')));

    // 计数器不再依赖英文 MaterialLocalizations。
    expect(find.bySemanticsLabel('0/20'), findsOneWidget);

    handle.dispose();
  });
}
