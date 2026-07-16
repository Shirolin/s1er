import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/image_load_policy.dart';
import 'package:s1_app/models/private_message.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/connectivity_provider.dart';
import 'package:s1_app/providers/pm_conversation_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/screens/pm_conversation_screen.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/pm_message_bubble.dart';
import 'package:s1_app/widgets/web_avatar.dart';

void main() {
  testWidgets('桌面私信会话使用限宽画布、头像和独立编辑卡片', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const touid = '535036';
    const state = PmConversationState(
      items: [
        PrivateMessage(
          id: '1',
          authorId: touid,
          authorName: 'Kiyohara_Yasuke',
          message: '收到，我来确认。',
          dateline: 1718585000,
          isOutgoing: false,
        ),
        PrivateMessage(
          id: '2',
          authorId: '426519',
          authorName: '本地用户',
          message: '谢谢。',
          dateline: 1718585600,
          isOutgoing: true,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          pmConversationProvider(touid).overrideWith(
            () => _SeededPmConversationNotifier(touid, state),
          ),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                avatarLoadPolicy: ImageLoadPolicy.manual,
              ),
            ),
          ),
          wifiConnectedProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const PmConversationScreen(
            touid: touid,
            partnerName: 'Kiyohara_Yasuke',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UID $touid'), findsOneWidget);
    expect(find.textContaining('Kiyohara_Yasuke  ·  '), findsOneWidget);
    expect(find.textContaining('本地用户  ·  '), findsOneWidget);
    expect(find.byType(WebAvatar), findsNWidgets(3));
    expect(find.text('回复 Kiyohara_Yasuke'), findsOneWidget);
    expect(find.byKey(const ValueKey('pm_desktop_composer')), findsOneWidget);

    final canvasSize = tester.getSize(
      find.byKey(const ValueKey('pm_conversation_canvas')),
    );
    expect(canvasSize.width, lessThanOrEqualTo(1040));
  });

  testWidgets('紧凑屏消息气泡保持无头像的原有布局', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: PmMessageBubble(
            message: PrivateMessage(
              id: '1',
              authorId: '535036',
              authorName: 'Kiyohara_Yasuke',
              message: '收到。',
              dateline: 1718585000,
              isOutgoing: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(WebAvatar), findsNothing);
    expect(find.textContaining('Kiyohara_Yasuke  ·  '), findsNothing);
    expect(find.text('收到。'), findsOneWidget);
  });
}

class _SeededPmConversationNotifier extends PmConversationNotifier {
  _SeededPmConversationNotifier(super.touid, this.seed);

  final PmConversationState seed;

  @override
  Future<PmConversationState> build() async => seed;
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true, username: '本地用户');
}
