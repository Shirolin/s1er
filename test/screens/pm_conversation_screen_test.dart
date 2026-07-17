import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/image_load_policy.dart';
import 'package:s1er/models/private_message.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/connectivity_provider.dart';
import 'package:s1er/providers/pm_conversation_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/pm_conversation_screen.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/web_avatar.dart';

const _touid = '535036';
const _sampleState = PmConversationState(
  items: [
    PrivateMessage(
      id: '1',
      authorId: _touid,
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

void main() {
  testWidgets('桌面私信会话使用限宽画布、头像和独立编辑卡片', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          pmConversationProvider(_touid).overrideWith(
            () => _SeededPmConversationNotifier(_touid, _sampleState),
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
            touid: _touid,
            partnerName: 'Kiyohara_Yasuke',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UID $_touid'), findsOneWidget);
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

  testWidgets('移动私信会话显示头像、时间和紧凑发送按钮', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          pmConversationProvider(_touid).overrideWith(
            () => _SeededPmConversationNotifier(_touid, _sampleState),
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
            touid: _touid,
            partnerName: 'Kiyohara_Yasuke',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UID $_touid'), findsNothing);
    expect(find.byType(WebAvatar), findsNWidgets(3));
    expect(find.textContaining('Kiyohara_Yasuke  ·  2024-'), findsOneWidget);
    expect(find.textContaining('本地用户  ·  2024-'), findsOneWidget);
    expect(find.byTooltip('发送私信'), findsOneWidget);
    expect(find.byKey(const ValueKey('pm_desktop_composer')), findsNothing);
    expect(tester.takeException(), isNull);
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
