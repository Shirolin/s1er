import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/post_share_service.dart';

import '../helpers/test_theme.dart';

ShareFloorData _floor(String pid) => ShareFloorData(
      post: Post.fromJson({
        'pid': pid,
        'message': '分享预览测试',
        'author': 'Tester',
        'authorid': '1',
        'dbdateline': '1',
        'number': '1',
      }),
      displayFloor: 1,
    );

Widget _wrap(
  Widget child, {
  AppSettings settings = const AppSettings(),
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        () => SettingsNotifier(initial: settings),
      ),
    ],
    child: wrapWithAppTheme(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: child,
      ),
    ),
  );
}

Future<ProviderContainer> _openSharePreview(WidgetTester tester) async {
  late ProviderContainer container;

  await tester.pumpWidget(
    _wrap(
      Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  unawaited(
                    PostShareService.share(
                      context: context,
                      floors: [_floor('1')],
                      tid: '99',
                    ),
                  );
                },
                child: const Text('打开分享'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('打开分享'));
  await tester.pumpAndSettle();

  expect(find.text('分享帖子'), findsOneWidget);
  expect(find.text('Logo'), findsOneWidget);
  expect(find.text('二维码'), findsOneWidget);

  return container;
}

void main() {
  testWidgets('preview footer chips toggle shareShowLogo and shareShowQr',
      (tester) async {
    final container = await _openSharePreview(tester);

    expect(container.read(settingsProvider).shareShowLogo, isTrue);
    expect(container.read(settingsProvider).shareShowQr, isTrue);

    await tester.tap(find.text('Logo'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowLogo, isFalse);

    await tester.tap(find.text('Logo'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowLogo, isTrue);

    await tester.tap(find.text('二维码'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowQr, isFalse);

    await tester.tap(find.text('二维码'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowQr, isTrue);
  });

  testWidgets('QR info button shows SnackBar inside the preview sheet',
      (tester) async {
    await _openSharePreview(tester);

    const hint = '部分平台会对带码图片限流';
    await tester.tap(find.byTooltip(hint));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(hint),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
  });
}
