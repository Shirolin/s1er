import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/image_load_policy.dart';
import 'package:s1er/providers/connectivity_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/avatar_fallback.dart';
import 'package:s1er/widgets/s1_click_region.dart';
import 'package:s1er/widgets/web_avatar.dart';

void main() {
  testWidgets('WebAvatar shows letter fallback when avatar policy is manual',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial:
                  const AppSettings(avatarLoadPolicy: ImageLoadPolicy.manual),
            ),
          ),
          wifiConnectedProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: WebAvatar(
              url: 'https://avatar.stage1st.com/avatar.php?uid=1&size=small',
              fallbackLetter: 'A',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AvatarFallbackLetter), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    final region = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(WebAvatar),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(region.cursor, SystemMouseCursors.click);
  });

  testWidgets('WebAvatar tap requests load under manual policy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial:
                  const AppSettings(avatarLoadPolicy: ImageLoadPolicy.manual),
            ),
          ),
          wifiConnectedProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: WebAvatar(
              url: 'https://avatar.stage1st.com/avatar.php?uid=1&size=small',
              fallbackLetter: 'A',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(S1ClickRegion));
    await tester.pump();

    expect(find.byType(AvatarFallbackLetter), findsNothing);
  });
}
