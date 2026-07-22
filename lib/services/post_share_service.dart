// ignore_for_file: unawaited_futures

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/poll.dart';
import '../models/share_floor_data.dart';
import '../models/share_image_format.dart';
import '../providers/image_bytes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/bbcode_parser.dart';
import '../utils/gallery_image_saver.dart';
import '../utils/share_capture_policy.dart';
import '../utils/share_image_stitch.dart';
import '../utils/share_native_image_encoder.dart';
import '../utils/share_rgba_flatten.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/share_card.dart';
import '../widgets/s1_click_region.dart';
import '../widgets/web_image_stub.dart'
    if (dart.library.html) '../widgets/web_image_html.dart';
import 'share_browser_image_encode_stub.dart'
    if (dart.library.html) 'share_browser_image_encode_web.dart'
    as browser_encode;

/// Encoded share-card bytes plus the format that actually landed in [bytes]
/// (may differ from the user preference when native encode falls back).
class _EncodedShareImage {
  const _EncodedShareImage(this.bytes, this.format);

  final Uint8List bytes;
  final ShareImageFormat format;

  String get extension => format.extension;
  String get mimeType => format.mimeType;
}

/// Captures post floor(s) as a designed card image and shares or saves it.
class PostShareService {
  PostShareService._();

  /// Toast after system share completes; null when the user cancelled.
  @visibleForTesting
  static String? toastMessageForShareResult(ShareResultStatus status) {
    return switch (status) {
      ShareResultStatus.success => '分享成功',
      ShareResultStatus.unavailable => '已打开分享',
      ShareResultStatus.dismissed => null,
    };
  }

  @visibleForTesting
  static String fileNameFor({
    required List<ShareFloorData> floors,
    required ShareImageFormat format,
    String? tid,
  }) {
    assert(floors.isNotEmpty);
    if (floors.length == 1) {
      return 's1_${floors.first.post.pid}${format.extension}';
    }
    final id = (tid != null && tid.isNotEmpty) ? tid : 't';
    return 's1_${id}_${floors.first.post.pid}_x${floors.length}'
        '${format.extension}';
  }

  static Future<void> share({
    required BuildContext context,
    required List<ShareFloorData> floors,
    String? threadSubject,
    ThreadPoll? poll,
    String? tid,
  }) async {
    if (floors.isEmpty) return;
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: S1Shape.bottomSheetShape,
      builder: (_) {
        return _SharePreviewSheet(
          floors: floors,
          threadSubject: threadSubject,
          poll: poll,
          tid: tid,
        );
      },
    );
    if (!context.mounted || message == null || message.isEmpty) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    S1SnackBar.show(context, message: message);
  }
}

class _SharePreviewSheet extends ConsumerStatefulWidget {
  const _SharePreviewSheet({
    required this.floors,
    this.threadSubject,
    this.poll,
    this.tid,
  });

  final List<ShareFloorData> floors;
  final String? threadSubject;
  final ThreadPoll? poll;
  final String? tid;

  @override
  ConsumerState<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

enum _FooterState { idle, capturing, error }

class _SharePreviewSheetState extends ConsumerState<_SharePreviewSheet> {
  late final ShareCaptureKeys _captureKeys =
      ShareCaptureKeys(floorCount: widget.floors.length);
  _FooterState _state = _FooterState.idle;
  String _statusMessage = '';

  late ShareImageFormat _shareImageFormat;
  late double _sharePixelRatio;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _shareImageFormat = settings.shareImageFormat;
    _sharePixelRatio = settings.sharePixelRatio;
  }

  String _fileNameFor(ShareImageFormat format) => PostShareService.fileNameFor(
        floors: widget.floors,
        format: format,
        tid: widget.tid,
      );

  Future<void> _captureAndShare() async {
    if (_state != _FooterState.idle) return;
    S1Haptics.medium();
    setState(() => _state = _FooterState.capturing);

    final encoded = await _captureBytes();
    if (!mounted) return;

    if (encoded == null) {
      if (_state != _FooterState.error) {
        _showStatus('生成图片失败，请稍后重试', isError: true);
      }
      return;
    }

    try {
      if (kIsWeb) {
        await downloadImageWeb(encoded.bytes, _fileNameFor(encoded.format));
        if (!mounted) return;
        _finishWithMessage('下载已开始');
        return;
      }

      final result = await _shareViaSystem(encoded);
      if (!mounted) return;
      final toast = PostShareService.toastMessageForShareResult(result.status);
      if (toast == null) {
        _finishQuietly();
      } else {
        _finishWithMessage(toast);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('分享失败: $e', isError: true);
    }
  }

  Future<void> _captureAndSave() async {
    if (_state != _FooterState.idle) return;
    S1Haptics.medium();
    setState(() => _state = _FooterState.capturing);

    final encoded = await _captureBytes();
    if (!mounted) return;

    if (encoded == null) {
      if (_state != _FooterState.error) {
        _showStatus('生成图片失败，请稍后重试', isError: true);
      }
      return;
    }

    try {
      if (kIsWeb) {
        await downloadImageWeb(encoded.bytes, _fileNameFor(encoded.format));
      } else {
        await saveImageBytesToGallery(
          bytes: encoded.bytes,
          fileName: _fileNameFor(encoded.format),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('保存失败: $e', isError: true);
      return;
    }

    if (!mounted) return;
    _finishWithMessage(kIsWeb ? '下载已开始' : '已保存到相册');
  }

  void _showStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _state = isError ? _FooterState.error : _FooterState.idle;
    });
  }

  void _finishWithMessage(String message) {
    if (mounted) Navigator.pop(context, message);
  }

  void _finishQuietly() {
    if (mounted) Navigator.pop(context);
  }

  void _dismissError() {
    setState(() => _state = _FooterState.idle);
  }

  Future<void> _waitUntilReady() async {
    final urls = <String>{};
    for (final floor in widget.floors) {
      final html = BbcodeParser.parse(floor.post.message);
      urls.addAll(BbcodeParser.extractImages(html));
      final avatar = floor.post.avatar;
      if (avatar != null && avatar.isNotEmpty) {
        urls.add(avatar);
      }
    }
    if (urls.isEmpty) return;
    await Future.wait(urls.map(_fetchImageBytes));
  }

  Future<void> _fetchImageBytes(String url) async {
    try {
      await ref
          .read(imageBytesProvider(url).future)
          .timeout(const Duration(seconds: 5));
    } on Object {
      // Image fetch failure is non-fatal for the screenshot.
    }
  }

  Future<_EncodedShareImage?> _captureBytes() async {
    await _waitUntilReady();
    if (!mounted) return null;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final fullBoundary = _captureKeys.full.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (fullBoundary == null) return null;

    final logicalSize = fullBoundary.size;
    final estimated = estimateShareCapturePixels(
      logicalWidth: logicalSize.width,
      logicalHeight: logicalSize.height,
      pixelRatio: _sharePixelRatio,
    );

    if (exceedsShareCaptureHardCap(estimatedCapturePixels: estimated)) {
      _showStatus(
        '内容过高无法生成，请少选几层或降低分享清晰度',
        isError: true,
      );
      return null;
    }

    final useChunks = shouldUseChunkedShareCapture(
      floorCount: widget.floors.length,
      estimatedCapturePixels: estimated,
    );

    if (!useChunks) {
      return _captureFromRepaint(fullBoundary, _sharePixelRatio);
    }

    return _captureChunkedAndEncode();
  }

  Future<_EncodedShareImage?> _captureChunkedAndEncode() async {
    final keys = <GlobalKey>[
      _captureKeys.header,
      ..._captureKeys.floors,
      _captureKeys.footer,
    ];
    final strips = <ShareRgbaStrip>[];

    try {
      for (final key in keys) {
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return null;
        final strip = await _rgbaStripFromBoundary(boundary, _sharePixelRatio);
        if (strip == null) return null;
        strips.add(strip);
      }

      final stitched = await stitchRgbaVerticallyAsync(strips);
      if (exceedsShareCaptureHardCap(
        estimatedCapturePixels: stitched.width * stitched.height,
      )) {
        _showStatus(
          '内容过高无法生成，请少选几层或降低分享清晰度',
          isError: true,
        );
        return null;
      }

      final image = await _imageFromRgba(stitched);
      try {
        return await _encode(image);
      } finally {
        image.dispose();
      }
    } on Object {
      return null;
    }
  }

  Future<ShareRgbaStrip?> _rgbaStripFromBoundary(
    RenderRepaintBoundary boundary,
    double pixelRatio,
  ) async {
    ui.Image? image;
    try {
      image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      // Copy so we can dispose the GPU image immediately.
      return ShareRgbaStrip(
        bytes: Uint8List.fromList(bytes),
        width: image.width,
        height: image.height,
      );
    } on Object {
      await WidgetsBinding.instance.endOfFrame;
      image?.dispose();
      image = null;
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData == null) return null;
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        return ShareRgbaStrip(
          bytes: Uint8List.fromList(bytes),
          width: image.width,
          height: image.height,
        );
      } on Object {
        return null;
      }
    } finally {
      image?.dispose();
    }
  }

  Future<ui.Image> _imageFromRgba(ShareRgbaStrip strip) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      strip.bytes,
      strip.width,
      strip.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Future<_EncodedShareImage?> _captureFromRepaint(
    RenderRepaintBoundary renderObject,
    double pixelRatio,
  ) async {
    ui.Image? image;
    try {
      image = await renderObject.toImage(pixelRatio: pixelRatio);
      return await _encode(image);
    } on Object {
      await WidgetsBinding.instance.endOfFrame;
      image?.dispose();
      image = null;
      try {
        image = await renderObject.toImage(pixelRatio: pixelRatio);
        return await _encode(image);
      } on Object {
        return null;
      }
    } finally {
      image?.dispose();
    }
  }

  Future<_EncodedShareImage> _encode(ui.Image image) {
    switch (_shareImageFormat) {
      case ShareImageFormat.png:
        return _encodePng(image);
      case ShareImageFormat.jpeg:
        return _encodeJpeg(image);
      case ShareImageFormat.webp:
        return _encodeWebp(image);
    }
  }

  Future<_EncodedShareImage> _encodePng(ui.Image image) async {
    final skiaPng = await _encodePngSkia(image);
    if (kIsWeb) {
      return _EncodedShareImage(skiaPng, ShareImageFormat.png);
    }

    final optimized = await encodeSharePngOptimized(skiaPng);
    return _EncodedShareImage(optimized ?? skiaPng, ShareImageFormat.png);
  }

  Future<Uint8List> _encodePngSkia(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<_EncodedShareImage> _encodeJpeg(ui.Image image) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromImage(image);
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: 'image/jpeg',
        quality: 0.85,
      );
      if (browserBytes != null) {
        return _EncodedShareImage(browserBytes, ShareImageFormat.jpeg);
      }
      return _EncodedShareImage(
        await _encodePngSkia(image),
        ShareImageFormat.png,
      );
    }

    final skiaPng = await _encodePngSkia(image);
    final jpeg = await encodeShareJpegFromPng(skiaPng);
    if (jpeg != null) {
      return _EncodedShareImage(jpeg, ShareImageFormat.jpeg);
    }

    final optimized = await encodeSharePngOptimized(skiaPng);
    return _EncodedShareImage(optimized ?? skiaPng, ShareImageFormat.png);
  }

  Future<_EncodedShareImage> _encodeWebp(ui.Image image) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromImage(image);
      final browserBytes = await browser_encode.encodeRgbaWithBrowser(
        rgbaBytes: opaque.bytes,
        width: opaque.width,
        height: opaque.height,
        mimeType: 'image/webp',
        quality: 0.85,
      );
      if (browserBytes != null) {
        return _EncodedShareImage(browserBytes, ShareImageFormat.webp);
      }
      return _EncodedShareImage(
        await _encodePngSkia(image),
        ShareImageFormat.png,
      );
    }

    final skiaPng = await _encodePngSkia(image);
    final webp = await encodeShareWebpFromPng(skiaPng);
    if (webp != null) {
      return _EncodedShareImage(webp, ShareImageFormat.webp);
    }

    final optimized = await encodeSharePngOptimized(skiaPng);
    return _EncodedShareImage(optimized ?? skiaPng, ShareImageFormat.png);
  }

  Future<({Uint8List bytes, int width, int height})> _opaqueRgbaFromImage(
    ui.Image image,
  ) async {
    final width = image.width;
    final height = image.height;
    final scheme = Theme.of(context).colorScheme;
    final card = S1Surface.card(scheme);
    final bgR = (card.r * 255).round();
    final bgG = (card.g * 255).round();
    final bgB = (card.b * 255).round();

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final raw = byteData!;
    final rgbaBytes = raw.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );

    final opaque = await flattenRgbaOntoOpaqueRgbaAsync(
      rgba: rgbaBytes,
      width: width,
      height: height,
      bgR: bgR,
      bgG: bgG,
      bgB: bgB,
    );
    return (bytes: opaque, width: width, height: height);
  }

  Future<ShareResult> _shareViaSystem(_EncodedShareImage encoded) async {
    final fileName = _fileNameFor(encoded.format);
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    final staged = XFile.fromData(
      encoded.bytes,
      mimeType: encoded.mimeType,
      name: fileName,
    );
    await staged.saveTo(path);
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: encoded.mimeType, name: fileName)],
        subject: fileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final title = widget.floors.length > 1
        ? '分享 ${widget.floors.length} 个楼层'
        : '分享帖子';

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    clipBehavior: Clip.hardEdge,
                    child: ShareCard(
                      captureKeys: _captureKeys,
                      floors: widget.floors,
                      threadSubject: widget.threadSubject,
                      poll: widget.poll,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: S1Motion.short,
              child: _buildFooter(scheme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      key: ValueKey(_state),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: S1Surface.card(scheme),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: S1Alpha.subtle),
          ),
        ),
      ),
      child: switch (_state) {
        _FooterState.idle => _buildActions(),
        _FooterState.capturing => _buildCapturing(scheme, textTheme),
        _FooterState.error => _buildError(scheme, textTheme),
      },
    );
  }

  Widget _buildActions() {
    if (kIsWeb) {
      return FilledButton.icon(
        onPressed: _captureAndSave,
        icon: const Icon(Icons.download_outlined),
        label: const Text('下载图片'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _captureAndSave,
            icon: const Icon(Icons.download_outlined),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            label: const Text(
              '下载图片',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _captureAndShare,
            icon: const Icon(Icons.share_outlined),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            label: const Text(
              '分享',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapturing(ColorScheme scheme, TextTheme textTheme) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '正在生成图片...',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme scheme, TextTheme textTheme) {
    return S1ClickRegion(
      onTap: _dismissError,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 20, color: scheme.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _statusMessage,
                style: textTheme.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '轻触重试',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
