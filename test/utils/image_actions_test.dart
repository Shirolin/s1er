import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/models/share_save_mode.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/utils/gallery_image_saver.dart';
import 'package:s1er/utils/image_actions.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/test_theme.dart';

Uint8List _pngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 80, 80));
  return Uint8List.fromList(img.encodePng(image));
}

const _url = 'https://img.stage1st.com/forum/photo.png';

Widget _harness(Widget child, {AppSettings settings = const AppSettings()}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        () => SettingsNotifier(initial: settings),
      ),
    ],
    child: wrapWithAppTheme(child),
  );
}

Widget _menuLauncher(
  ImageActionsSpec spec, {
  bool? canDownload,
  bool? canShare,
  bool? canCopyImage,
}) {
  return Builder(
    builder: (context) => Center(
      child: FilledButton(
        onPressed: () => unawaited(
          showImageActions(
            context,
            spec,
            canDownload: canDownload,
            canShare: canShare,
            canCopyImage: canCopyImage,
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showImageActions', () {
    testWidgets('shows download / share / copy / info on supported platforms',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          _menuLauncher(
            const ImageActionsSpec(fullUrl: _url, fileName: 'photo.png'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('下载'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('复制图片'), findsOneWidget);
      expect(find.text('复制链接'), findsOneWidget);
      expect(find.text('图片信息'), findsOneWidget);
    });

    testWidgets('hides download / share / copy image when unsupported',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          _menuLauncher(
            const ImageActionsSpec(fullUrl: _url, fileName: 'photo.png'),
            canDownload: false,
            canShare: false,
            canCopyImage: false,
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('下载'), findsNothing);
      expect(find.text('分享'), findsNothing);
      expect(find.text('复制图片'), findsNothing);
      expect(find.text('复制链接'), findsOneWidget);
      expect(find.text('图片信息'), findsOneWidget);
    });

    testWidgets('copy link writes the full URL to clipboard', (tester) async {
      final clipboard = <String, String?>{};
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboard['text'] =
                  (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return clipboard;
            default:
              return null;
          }
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        _harness(
          _menuLauncher(
            const ImageActionsSpec(fullUrl: _url, fileName: 'photo.png'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('复制链接'));
      await tester.pumpAndSettle();

      final data = await Clipboard.getData('text/plain');
      expect(data?.text, _url);
      expect(find.text('已复制图片链接'), findsOneWidget);
    });

    testWidgets('image info opens sheet with metadata', (tester) async {
      final bytes = _pngBytes(width: 40, height: 30);
      await tester.pumpWidget(
        _harness(
          _menuLauncher(
            ImageActionsSpec(
              fullUrl: _url,
              fileName: 'photo.png',
              bytes: bytes,
              imageWidth: 40,
              imageHeight: 30,
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('图片信息'));
      await tester.pumpAndSettle();

      expect(find.text('文件名'), findsOneWidget);
      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('格式'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);
      expect(find.text('尺寸'), findsOneWidget);
      expect(find.text('40 × 30 px'), findsOneWidget);
      expect(find.text('大小'), findsOneWidget);
      expect(find.text(formatBytesSize(bytes.length)), findsOneWidget);
    });
  });

  group('downloadImageBytes', () {
    testWidgets('saves via injected saver and toasts success', (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);
      String? savedFileName;
      Uint8List? savedBytes;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  downloadImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    saver: ({
                      required bytes,
                      customDirectory,
                      required fileName,
                      saveMode = ShareSaveMode.autoDir,
                    }) async {
                      savedBytes = bytes;
                      savedFileName = fileName;
                      return SaveImageResultStatus.success;
                    },
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(savedBytes, same(bytes));
      expect(savedFileName, 'photo.png');
      expect(find.text('已保存到相册'), findsOneWidget);
    });

    testWidgets('toasts custom directory message when configured',
        (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  downloadImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    saver: ({
                      required bytes,
                      customDirectory,
                      required fileName,
                      saveMode = ShareSaveMode.autoDir,
                    }) async =>
                        SaveImageResultStatus.success,
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
          settings: const AppSettings(customExportPath: '/custom'),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('已保存至自定义目录'), findsOneWidget);
    });

    testWidgets('does not toast when the user cancels', (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  downloadImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    saver: ({
                      required bytes,
                      customDirectory,
                      required fileName,
                      saveMode = ShareSaveMode.autoDir,
                    }) async =>
                        SaveImageResultStatus.cancelled,
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('shareImageBytes', () {
    testWidgets('shares the image file via the injected share fn',
        (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);
      ShareParams? captured;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  shareImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    delay: () async {},
                    share: (params) async {
                      captured = params;
                      return const ShareResult('', ShareResultStatus.success);
                    },
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.files, hasLength(1));
      expect(captured!.files!.first.mimeType, 'image/png');
      expect(captured!.fileNameOverrides, ['photo.png']);
      expect(find.text('分享成功'), findsOneWidget);
    });

    testWidgets('does not toast when the share sheet is dismissed',
        (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  shareImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    delay: () async {},
                    share: (params) async =>
                        const ShareResult('', ShareResultStatus.dismissed),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('copyImageBytes', () {
    testWidgets('copies the image bytes via the injected copier',
        (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);
      Uint8List? copied;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  copyImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    copier: (image) async {
                      copied = image;
                    },
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(copied, same(bytes));
      expect(find.text('已复制图片'), findsOneWidget);
    });

    testWidgets('toasts error when copying fails', (tester) async {
      final bytes = _pngBytes(width: 20, height: 20);

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  copyImageBytes(
                    context,
                    ImageActionsSpec(
                      fullUrl: _url,
                      fileName: 'photo.png',
                      bytes: bytes,
                    ),
                    copier: (image) async {
                      throw StateError('clipboard unavailable');
                    },
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('复制失败'), findsOneWidget);
    });
  });
}
