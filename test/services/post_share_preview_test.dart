import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
import 'package:s1er/models/share_image_format.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/post_share_service.dart';
import 'package:s1er/utils/gallery_image_saver.dart';
import 'package:s1er/utils/share_encoder.dart';
import 'package:s1er/utils/share_image_stitch.dart';

import '../helpers/ironpress_test_lib.dart';
import '../helpers/test_theme.dart';

ShareFloorData _floorWithoutImages(String pid) => ShareFloorData(
      post: Post(
        pid: pid,
        message: '分享预览测试',
        author: 'Tester',
        authorId: '1',
        dateline: 1,
        floor: 1,
      ),
      displayFloor: 1,
    );

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

/// 截图编码（`toByteData` / native）在假异步时钟下不会完成，进度圈又会持续要帧，
/// `pumpAndSettle` 会因此超时。交替泵帧并让出真实异步，直到 [done]。
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

void main() {
  // 复制「固定 PNG」只有在 native 编码可用时才可证伪：不可用时 WebP 也会
  // 降级成 PNG，断言会空过。先把 ironpress 动态库放到 flutter test 能加载的位置。
  setUpAll(ensureIronpressTestNativeLib);

  testWidgets('preview footer chips toggle shareShowLogo and shareShowQr',
      (tester) async {
    final container = await _openSharePreview(tester);

    expect(container.read(settingsProvider).shareShowLogo, isTrue);
    expect(container.read(settingsProvider).shareShowQr, isTrue);

    final logoChip = find.widgetWithText(FilterChip, 'Logo');
    final qrChip = find.widgetWithText(FilterChip, '二维码');

    await tester.ensureVisible(logoChip);
    await tester.tap(logoChip);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowLogo, isFalse);

    await tester.tap(logoChip);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowLogo, isTrue);

    await tester.ensureVisible(qrChip);
    await tester.tap(qrChip);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowQr, isFalse);

    await tester.tap(qrChip);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).shareShowQr, isTrue);
  });

  testWidgets('QR limit hint is visible as helper text', (tester) async {
    await _openSharePreview(tester);

    final hint = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('部分平台会对带码图片限流'),
    );
    expect(hint, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '二维码'));
    await tester.pumpAndSettle();
    expect(hint, findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '二维码'));
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
  });

  testWidgets('copy writes PNG even when the export format is WebP',
      (tester) async {
    // 对照：native 不可用时 WebP 会降级成 PNG，下面的断言无法区分
    // 「复制强制 PNG」与「降级」，此时显式跳过而不是空过。
    final control = await tester.runAsync(
      () => const ShareEncoder(
        format: ShareImageFormat.webp,
        background: Color(0xFFFFFFFF),
      ).encodeStrip(
        ShareRgbaStrip(
          bytes: Uint8List.fromList(List.filled(2 * 2 * 4, 255)),
          width: 2,
          height: 2,
        ),
      ),
    );
    if (control?.format != ShareImageFormat.webp) {
      markTestSkipped('ironpress native WebP encoder unavailable');
      return;
    }

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    Uint8List? copied;
    try {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(
                        PostShareService.share(
                          context: context,
                          floors: [_floorWithoutImages('1')],
                          tid: '99',
                          imageCopier: (bytes) async {
                            copied = bytes;
                          },
                        ),
                      );
                    },
                    child: const Text('打开分享'),
                  ),
                ),
              );
            },
          ),
          settings: const AppSettings(
            shareImageFormat: ShareImageFormat.webp,
            shareShowLogo: false,
            shareShowQr: false,
          ),
        ),
      );

      await tester.tap(find.text('打开分享'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '复制'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '分享'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '下载图片'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '复制'));
      await _pumpUntil(tester, () => copied != null);
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      expect(isPngImageBytes(copied!), isTrue);
      expect(find.text('已复制图片'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('copy failure stays on the sheet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(
                        PostShareService.share(
                          context: context,
                          floors: [_floorWithoutImages('1')],
                          tid: '99',
                          imageCopier: (_) async {
                            throw StateError('clipboard unavailable');
                          },
                        ),
                      );
                    },
                    child: const Text('打开分享'),
                  ),
                ),
              );
            },
          ),
          settings: const AppSettings(
            shareShowLogo: false,
            shareShowQr: false,
          ),
        ),
      );

      await tester.tap(find.text('打开分享'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '复制'));
      await _pumpUntil(
        tester,
        () => find.textContaining('复制失败').evaluate().isNotEmpty,
      );
      await tester.pump();

      expect(find.textContaining('复制失败'), findsOneWidget);
      expect(find.text('分享帖子'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
