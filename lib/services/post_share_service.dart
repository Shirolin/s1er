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
import '../models/post.dart';
import '../models/share_image_format.dart';
import '../providers/image_bytes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/bbcode_parser.dart';
import '../utils/gallery_image_saver.dart';
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

/// Captures a post as a designed card image and shares or saves it.
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

  static Future<void> share({
    required BuildContext context,
    required Post post,
    int? displayFloor,
    String? threadSubject,
    ThreadPoll? poll,
  }) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: S1Shape.bottomSheetShape,
      // Standard-height sheet: dismiss via drag / scrim / back — no close chrome.
      builder: (_) {
        return _SharePreviewSheet(
          post: post,
          displayFloor: displayFloor,
          threadSubject: threadSubject,
          poll: poll,
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
    required this.post,
    this.displayFloor,
    this.threadSubject,
    this.poll,
  });

  final Post post;
  final int? displayFloor;
  final String? threadSubject;
  final ThreadPoll? poll;

  @override
  ConsumerState<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

/// Footer visual states.
///
/// [idle]     — action buttons visible.
/// [capturing] — spinner shown.
/// [error]    — error shown in red, user can retry or dismiss.
enum _FooterState { idle, capturing, error }

class _SharePreviewSheetState extends ConsumerState<_SharePreviewSheet> {
  final GlobalKey _captureKey = GlobalKey();
  _FooterState _state = _FooterState.idle;
  String _statusMessage = '';

  late ShareImageFormat _shareImageFormat;
  late double _sharePixelRatio;

  @override
  void initState() {
    super.initState();
    // Capture current settings values.
    final settings = ref.read(settingsProvider);
    _shareImageFormat = settings.shareImageFormat;
    _sharePixelRatio = settings.sharePixelRatio;
  }

  String _fileNameFor(ShareImageFormat format) =>
      's1_${widget.post.pid}${format.extension}';

  Future<void> _captureAndShare() async {
    if (_state != _FooterState.idle) return;
    S1Haptics.medium();
    setState(() => _state = _FooterState.capturing);

    final encoded = await _captureBytes();
    if (!mounted) return;

    if (encoded == null) {
      _showStatus('生成图片失败，请稍后重试', isError: true);
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
      _showStatus('生成图片失败，请稍后重试', isError: true);
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

  /// Shows an error inline at the footer, replacing the buttons.
  /// The user can tap to dismiss and retry.
  void _showStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _state = isError ? _FooterState.error : _FooterState.idle;
    });
  }

  /// Close sheet and let [PostShareService.share] show [message] on the
  /// parent scaffold (sheet context is gone after pop).
  void _finishWithMessage(String message) {
    if (mounted) Navigator.pop(context, message);
  }

  /// Close without a toast (user dismissed the system share sheet).
  void _finishQuietly() {
    if (mounted) Navigator.pop(context);
  }

  /// Retry after error — go back to idle buttons.
  void _dismissError() {
    setState(() => _state = _FooterState.idle);
  }

  /// Wait for images referenced in the post to become available before
  /// capturing, so the screenshot is less likely to show loading placeholders.
  Future<void> _waitUntilReady() async {
    final html = BbcodeParser.parse(widget.post.message);
    final urls = BbcodeParser.extractImages(html).toSet();
    if (widget.post.avatar != null && widget.post.avatar!.isNotEmpty) {
      urls.add(widget.post.avatar!);
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
    // Let ShareCard rebuild with MemoryImage / letter fallback after prefetch.
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final renderObject = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (renderObject == null) return null;
    final pixelRatio = _sharePixelRatio;

    return _captureFromRepaint(renderObject, pixelRatio);
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
      // First attempt failed — retry once after an extra frame
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

  /// PNG: Skia capture, then Native oxipng via ironpress when available.
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

    // ironpress accepts encoded buffers; Skia PNG is a fast intermediate.
    final skiaPng = await _encodePngSkia(image);
    final webp = await encodeShareWebpFromPng(skiaPng);
    if (webp != null) {
      return _EncodedShareImage(webp, ShareImageFormat.webp);
    }

    // Native encode failed — fall back to (possibly oxipng) PNG.
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

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title only — dismiss via drag handle / scrim / back (no close chrome)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '分享帖子',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Card preview
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    clipBehavior: Clip.hardEdge,
                    child: ShareCard(
                      captureKey: _captureKey,
                      post: widget.post,
                      displayFloor: widget.displayFloor,
                      threadSubject: widget.threadSubject,
                      poll: widget.poll,
                    ),
                  ),
                ),
              ),
            ),

            // Footer
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

    // Equal width + single-line labels so long Chinese text does not wrap
    // when download/save and share appear side by side.
    // Do not override label TextStyle colors — Filled/Outlined inherit
    // onPrimary / primary from the button theme (MD3 contrast contract).
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
            Text(
              _statusMessage,
              style: textTheme.bodyMedium?.copyWith(color: scheme.error),
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
