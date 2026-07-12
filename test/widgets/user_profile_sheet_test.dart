import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/widgets/user_profile_sheet.dart';

void main() {
  testWidgets('showUserProfileSheet renders stats and details', (tester) async {
    final user = User(
      uid: '123',
      username: '测试用户',
      groupTitle: '用户组',
      credits: 102910,
      posts: 5256,
      combat: 563,
      deadfish: 40,
      regdate: '2019-3-19 11:02:33',
      oltime: 100,
      following: 10,
      follower: 20,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showUserProfileSheet(
                  context,
                  future: Future.value(user),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('用户组'), findsOneWidget);
    expect(find.text('积分'), findsOneWidget);
    expect(find.text('死鱼'), findsOneWidget);
    expect(find.text('10万'), findsOneWidget);
    expect(find.text('注册时间'), findsOneWidget);
    expect(find.text('2019-3-19 11:02'), findsOneWidget);
  });
}
