// ignore_for_file: unawaited_futures

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../models/share_image_format.dart';
import '../providers/image_bytes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/bbcode_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/share_card.dart';
import '../widgets/web_image_stub.dart'
    if (dart.library.html) '../widgets/web_image_html.dart';

/// Captures a post as a designed card image and shares or saves it.
class PostShareService {
  PostShareService._();

  static Future<void> share({
    required BuildContext context,
    required Post post,
    int? displayFloor,
    String? threadSubject,
  }) async {
    await showModalBottomSheet<void>(
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
        );
      },
    );
  }
}

class _SharePreviewSheet extends ConsumerStatefulWidget {
  const _SharePreviewSheet({
    required this.post,
    this.displayFloor,
    this.threadSubject,
  });

  final Post post;
  final int? displayFloor;
  final String? threadSubject;

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
  late int _sharePixelRatio;

  @override
  void initState() {
    super.initState();
    // Capture current settings values.
    final settings = ref.read(settingsProvider);
    _shareImageFormat = settings.shareImageFormat;
    _sharePixelRatio = settings.sharePixelRatio;
  }

  String get _fileName {
    final ext = _shareImageFormat.extension;
    return 's1_${widget.post.pid}$ext';
  }

  String get _mimeType => _shareImageFormat.mimeType;

  Future<void> _captureAndShare() async {
    if (_state != _FooterState.idle) return;
    HapticFeedback.mediumImpact();
    setState(() => _state = _FooterState.capturing);

    final bytes = await _captureBytes();
    if (!mounted) return;

    if (bytes == null) {
      _showStatus('生成图片失败，请稍后重试', isError: true);
      return;
    }

    try {
      if (kIsWeb) {
        await downloadImageWeb(bytes, _fileName);
      } else {
        await _shareViaSystem(bytes);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('分享失败: $e', isError: true);
      return;
    }

    if (!mounted) return;
    _autoClose();
  }

  Future<void> _captureAndSave() async {
    if (_state != _FooterState.idle) return;
    HapticFeedback.mediumImpact();
    setState(() => _state = _FooterState.capturing);

    final bytes = await _captureBytes();
    if (!mounted) return;

    if (bytes == null) {
      _showStatus('生成图片失败，请稍后重试', isError: true);
      return;
    }

    try {
      if (kIsWeb) {
        await downloadImageWeb(bytes, _fileName);
      } else {
        await Gal.putImageBytes(bytes, name: _fileName);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('保存失败: $e', isError: true);
      return;
    }

    _autoClose();
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

  /// Close the sheet without showing anything (success case: share/save
  /// are handled by the platform).
  void _autoClose() {
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

  Future<Uint8List?> _captureBytes() async {
    await _waitUntilReady();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final renderObject = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (renderObject == null) return null;
    final pixelRatio = _sharePixelRatio.toDouble();

    return _captureFromRepaint(renderObject, pixelRatio);
  }

  Future<Uint8List?> _captureFromRepaint(
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

  Future<Uint8List> _encode(ui.Image image) {
    if (_shareImageFormat == ShareImageFormat.png) {
      return _encodePng(image);
    }
    return _encodeJpeg(image);
  }

  Future<Uint8List> _encodePng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _encodeJpeg(ui.Image image) async {
    final width = image.width;
    final height = image.height;

    // Capture background color before async gap for JPEG compositing.
    final scheme = Theme.of(context).colorScheme;
    final bgR = (scheme.surfaceContainerLow.r * 255).round();
    final bgG = (scheme.surfaceContainerLow.g * 255).round();
    final bgB = (scheme.surfaceContainerLow.b * 255).round();

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgbaBytes = byteData!.buffer.asUint8List();

    final params = _JpegParams(rgbaBytes, width, height, bgR, bgG, bgB);

    if (kIsWeb) {
      return _encodeJpegSync(params);
    }
    return compute(_encodeJpegSync, params);
  }

  Future<void> _shareViaSystem(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, _fileName);
    final staged = XFile.fromData(bytes, mimeType: _mimeType, name: _fileName);
    await staged.saveTo(path);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: _mimeType, name: _fileName)],
        subject: _fileName,
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
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: S1Alpha.subtle),
          ),
        ),
      ),
      child: switch (_state) {
        _FooterState.idle => _buildActions(scheme, textTheme),
        _FooterState.capturing => _buildCapturing(scheme, textTheme),
        _FooterState.error => _buildError(scheme, textTheme),
      },
    );
  }

  Widget _buildActions(ColorScheme scheme, TextTheme textTheme) {
    if (kIsWeb) {
      return FilledButton.icon(
        onPressed: _captureAndSave,
        icon: const Icon(Icons.download_outlined),
        label: const Text('下载图片'),
      );
    }

    // Equal width + single-line labels so long Chinese text does not wrap
    // when download/save and share appear side by side.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _captureAndSave,
            icon: Icon(Icons.download_outlined, color: scheme.onSurfaceVariant),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            label: Text(
              '下载图片',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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
            label: Text(
              '分享',
              maxLines: 1,
              softWrap: false,
              style: textTheme.labelLarge,
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
    return GestureDetector(
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

/// Parameters for background isolate JPEG encoding.
class _JpegParams {
  _JpegParams(
    this.bytes,
    this.width,
    this.height,
    this.bgR,
    this.bgG,
    this.bgB,
  );

  final Uint8List bytes;
  final int width;
  final int height;
  final int bgR;
  final int bgG;
  final int bgB;
}

/// Top-level function for background isolate execution.
Uint8List _encodeJpegSync(_JpegParams params) {
  final src = img.Image.fromBytes(
    width: params.width,
    height: params.height,
    bytes: params.bytes.buffer,
    numChannels: 4,
  );
  final bg = img.Image(
    width: params.width,
    height: params.height,
    numChannels: 3,
  );
  final c = bg.getColor(params.bgR, params.bgG, params.bgB);
  bg.clear(c);
  img.compositeImage(bg, src);
  return img.encodeJpg(bg, quality: 90);
}
