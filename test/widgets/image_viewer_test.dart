import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/widgets/image_viewer.dart';

void main() {
  testWidgets('ImageViewer shows placeholder when showImages is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showImages: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: ImageViewer(
              imageUrl: 'https://example.com/image.jpg',
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('[图片]'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ImageViewer still renders emoticon when showImages is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showImages: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(
            body: ImageViewer(
              imageUrl:
                  'https://avatar.stage1st.com/000/00/00/01_avatar_small.jpg',
              isEmoticon: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('[图片]'), findsNothing);
  });
}
