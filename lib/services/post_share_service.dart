// ignore_for_file: unawaited_futures

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_icon_catalog.dart';
import '../models/poll.dart';
import '../models/share_floor_data.dart';
import '../models/share_image_format.dart';
import '../providers/image_bytes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/gallery_image_saver.dart';
import '../utils/share_capture_limits.dart';
import '../utils/share_capture_policy.dart';
import 'talker.dart';
import '../utils/share_capture_helpers.dart';
import '../utils/share_floor_strip_capture.dart';
import '../utils/share_image_stitch.dart';
import '../utils/share_native_image_encoder.dart';
import '../utils/share_rgba_encoder.dart';
import '../utils/share_rgba_flatten.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/image_viewer.dart';
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
  final GlobalKey _offscreenCaptureKey = GlobalKey();
  final ScrollController _offscreenScrollController = ScrollController();
  bool _offscreenFullCardCapture = false;
  _FooterState _state = _FooterState.idle;
  String _statusMessage = '';
  String _captureProgressMessage = '';
  String? _scaleExportNotice;

  late ShareImageFormat _shareImageFormat;
  late double _sharePixelRatio;
  late bool _shareAdvancedExport;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _shareImageFormat = settings.shareImageFormat;
    _sharePixelRatio = settings.sharePixelRatio;
    _shareAdvancedExport = settings.shareAdvancedExport;
  }

  @override
  void dispose() {
    _offscreenScrollController.dispose();
    super.dispose();
  }

  ShareCaptureLimits get _shareCaptureLimits =>
      ShareCaptureLimits.forCurrentPlatform(advanced: _shareAdvancedExport);

  ShareCaptureSizeInfo? _lastCaptureSize;

  void _rememberCaptureSize(ShareCaptureSizeInfo size) {
    _lastCaptureSize = size;
  }

  void _showHeightCapError(ShareCaptureSizeInfo size) {
    final detail = formatShareCaptureSizeDetail(size);
    talker.warning('Share capture exceeded cap: $detail');
    if (_shareAdvancedExport) {
      _showStatus(
        '内容仍超出设备能力：$detail。请减少楼层或图片',
        isError: true,
      );
    } else {
      _showStatus(
        '内容过高无法生成：$detail。'
        '请少选几层或降低分享清晰度。'
        '可在 设置 → 分享 → 高级导出 中开启',
        isError: true,
      );
    }
  }

  void _showCaptureFailure(String message) {
    final suffix = _lastCaptureSize == null
        ? ''
        : formatShareCaptureSizeShort(_lastCaptureSize!);
    final full = '$message$suffix';
    talker.warning('Share capture failed: $full');
    _showStatus(full, isError: true);
  }

  void _setCaptureProgress(String message) {
    if (!mounted || _state != _FooterState.capturing) return;
    setState(() => _captureProgressMessage = message);
  }

  String _fileNameFor(ShareImageFormat format) => PostShareService.fileNameFor(
        floors: widget.floors,
        format: format,
        tid: widget.tid,
      );

  Future<void> _captureAndShare() async {
    if (_state != _FooterState.idle) return;
    S1Haptics.medium();
    _scaleExportNotice = null;
    _captureProgressMessage = '';
    setState(() => _state = _FooterState.capturing);

    final encoded = await _captureBytes();
    if (!mounted) return;

    if (encoded == null) {
      if (_state != _FooterState.error) {
        _showCaptureFailure('生成图片失败，请稍后重试');
      }
      return;
    }

    try {
      if (kIsWeb) {
        await downloadImageWeb(encoded.bytes, _fileNameFor(encoded.format));
        if (!mounted) return;
        _finishWithMessage(_scaleExportNotice ?? '下载已开始');
        return;
      }

      final result = await _shareViaSystem(encoded);
      if (!mounted) return;
      final toast = PostShareService.toastMessageForShareResult(result.status);
      if (toast == null) {
        _finishQuietly();
      } else {
        final message =
            _scaleExportNotice == null ? toast : '$toast；$_scaleExportNotice';
        _finishWithMessage(message);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('分享失败: $e', isError: true);
    }
  }

  Future<void> _captureAndSave() async {
    if (_state != _FooterState.idle) return;
    S1Haptics.medium();
    _scaleExportNotice = null;
    _captureProgressMessage = '';
    setState(() => _state = _FooterState.capturing);

    final encoded = await _captureBytes();
    if (!mounted) return;

    if (encoded == null) {
      if (_state != _FooterState.error) {
        _showCaptureFailure('生成图片失败，请稍后重试');
      }
      return;
    }

    String successToast = '已保存到相册';
    try {
      if (kIsWeb) {
        await downloadImageWeb(encoded.bytes, _fileNameFor(encoded.format));
        successToast = '下载已开始';
      } else {
        final settings = ref.read(settingsProvider);
        final result = await saveImageBytesToGallery(
          bytes: encoded.bytes,
          fileName: _fileNameFor(encoded.format),
          customDirectory: settings.customExportPath,
          saveMode: settings.shareSaveMode,
        );
        if (result == SaveImageResultStatus.cancelled) {
          _finishQuietly();
          return;
        } else if (result == SaveImageResultStatus.fallbackSuccess) {
          successToast = '原目录不可用，已自动保存至系统图片文件夹';
        } else if (settings.customExportPath != null &&
            settings.customExportPath!.isNotEmpty) {
          successToast = '已保存至自定义目录';
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('保存失败: $e', isError: true);
      return;
    }

    if (!mounted) return;
    _finishWithMessage(_scaleExportNotice ?? successToast);
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

  Future<bool> _waitUntilReady() async {
    if (!mounted) return false;
    _setCaptureProgress('正在准备图片…');
    await _precacheShareLogo();
    if (!mounted) return false;

    final urls = collectShareImageUrls(widget.floors);
    if (urls.isEmpty) {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      return true;
    }

    var failedUrls = 0;
    final bytesByUrl = <String, Uint8List>{};
    await forEachConcurrent(urls, (url) async {
      final bytes = await _fetchImageBytes(url);
      if (bytes == null) {
        failedUrls++;
      } else {
        bytesByUrl[url] = bytes;
      }
    });

    if (shouldAbortSharePreload(
      totalUrls: urls.length,
      failedUrls: failedUrls,
    )) {
      talker.warning(
        'Share preload failed for $failedUrls/${urls.length} images',
      );
      _showCaptureFailure('图片加载失败过多，请检查网络后重试');
      return false;
    }
    if (failedUrls > 0) {
      talker.warning(
        'Share preload missing $failedUrls/${urls.length} images',
      );
    }

    if (!mounted) return false;
    final entries = bytesByUrl.entries.toList();
    await forEachConcurrent(entries, (entry) async {
      ImageViewer.primeMemoryCache(entry.key, entry.value);
      if (!mounted) return;
      final captureContext = context;
      if (!captureContext.mounted) return;
      await precacheImage(MemoryImage(entry.value), captureContext);
    });
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    return true;
  }

  Future<void> _precacheShareLogo() async {
    if (!mounted) return;
    if (!ref.read(settingsProvider).shareShowLogo) return;
    final iconId = ref.read(settingsProvider).appIcon;
    final asset = AppIconCatalog.find(iconId)?.previewAsset ??
        AppIconCatalog.defaultVariant.previewAsset;
    final image = AssetImage(asset);
    const logoSize = Size(ShareCard.logoSize, ShareCard.logoSize);
    final previewDpr = MediaQuery.devicePixelRatioOf(context);
    try {
      await _precacheShareLogoAt(
        image,
        devicePixelRatio: previewDpr,
        size: logoSize,
      );
      if (!mounted) return;
      if (_sharePixelRatio != previewDpr) {
        await _precacheShareLogoAt(
          image,
          devicePixelRatio: _sharePixelRatio,
          size: logoSize,
        );
      }
    } on Object catch (e, st) {
      talker.handle(e, st, 'Share logo precache failed: $asset');
    }
  }

  Future<void> _precacheShareLogoAt(
    AssetImage image, {
    required double devicePixelRatio,
    required Size size,
  }) {
    if (!mounted) return Future<void>.value();
    final config = ImageConfiguration(
      bundle: DefaultAssetBundle.of(context),
      devicePixelRatio: devicePixelRatio,
      locale: Localizations.maybeLocaleOf(context),
      textDirection: Directionality.maybeOf(context),
      size: size,
      platform: defaultTargetPlatform,
    );
    final stream = image.resolve(config);
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    return completer.future.whenComplete(() {
      stream.removeListener(listener);
    });
  }

  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      return await ref
          .read(imageBytesProvider(url).future)
          .timeout(const Duration(seconds: 15));
    } on Object {
      // Image fetch failure is non-fatal for the screenshot.
      return null;
    }
  }

  Future<bool> _waitForOffscreenScrollLayout() async {
    double? lastHeight;
    var stableFrames = 0;

    for (var i = 0; i < shareLayoutMaxAttempts; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;

      final height = _offscreenScrollController.hasClients
          ? measureScrollableLogicalHeight(_offscreenScrollController)
          : 0.0;
      stableFrames = advanceLayoutStability(
        lastHeight: lastHeight,
        currentHeight: height,
        stableFrames: stableFrames,
      );
      if (isLayoutStabilityReached(stableFrames: stableFrames)) {
        return true;
      }
      if (height > 0) {
        lastHeight = height;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  Future<bool> _waitForOffscreenImagesReady() async {
    const maxAttempts = 40;
    var readyFrames = 0;

    for (var i = 0; i < maxAttempts; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;

      final element = _offscreenCaptureKey.currentContext as Element?;
      if (!subtreeHasLoadingIndicator(element)) {
        readyFrames++;
        if (readyFrames >= shareLayoutStableFramesRequired) {
          return true;
        }
      } else {
        readyFrames = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  Future<_EncodedShareImage?> _captureBytes() async {
    if (!await _waitUntilReady()) return null;
    if (!mounted) return null;
    _setCaptureProgress('正在生成图片…');
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
    final limits = _shareCaptureLimits;
    final captureSize = shareCaptureSizeFromLogical(
      logicalWidth: logicalSize.width,
      logicalHeight: logicalSize.height,
      pixelRatio: _sharePixelRatio,
      maxPixels: limits.maxPixels,
    );
    _rememberCaptureSize(captureSize);
    final estimated = captureSize.totalPixels;

    if (exceedsShareCaptureHardCap(
      estimatedCapturePixels: estimated,
      advanced: _shareAdvancedExport,
      limits: limits,
    )) {
      _showHeightCapError(captureSize);
      return null;
    }

    final useChunks = shouldUseChunkedShareCapture(
      floorCount: widget.floors.length,
      estimatedCapturePixels: estimated,
    );

    if (!useChunks) {
      return _captureFromRepaint(fullBoundary, _sharePixelRatio);
    }

    final physicalWidth = (logicalSize.width * _sharePixelRatio).round();
    return _captureChunkedAndEncode(
      estimatedCapturePixels: estimated,
      physicalWidth: physicalWidth,
    );
  }

  Future<List<ShareRgbaStrip>> _captureFullCardScrollStrips() async {
    if (!mounted) return [];
    setState(() => _offscreenFullCardCapture = true);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    if (_offscreenScrollController.hasClients) {
      _offscreenScrollController.jumpTo(0);
    }

    final layoutReady = await _waitForOffscreenScrollLayout();
    if (!layoutReady) {
      if (mounted) setState(() => _offscreenFullCardCapture = false);
      _showCaptureFailure('分享卡布局未稳定，请稍后重试');
      return [];
    }

    final imagesReady = await _waitForOffscreenImagesReady();
    if (!imagesReady) {
      if (mounted) setState(() => _offscreenFullCardCapture = false);
      _showCaptureFailure('图片未加载完成，请稍后重试');
      return [];
    }

    final boundary = _offscreenCaptureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) setState(() => _offscreenFullCardCapture = false);
      return [];
    }

    final measuredHeight = _offscreenScrollController.hasClients
        ? measureScrollableLogicalHeight(_offscreenScrollController)
        : 0.0;
    if (measuredHeight <= 0) {
      if (mounted) setState(() => _offscreenFullCardCapture = false);
      return [];
    }

    final strips = await captureBoundaryAsStrips(
      boundary,
      pixelRatio: _sharePixelRatio,
      inFloorChunking: true,
      scrollController: _offscreenScrollController,
      totalLogicalHeight: measuredHeight,
      limits: _shareCaptureLimits,
    );

    if (mounted) setState(() => _offscreenFullCardCapture = false);
    if (strips.isEmpty && mounted) {
      _showCaptureFailure('长图截取不完整，请稍后重试');
    }
    return strips;
  }

  Future<_EncodedShareImage?> _captureChunkedAndEncode({
    required int estimatedCapturePixels,
    required int physicalWidth,
  }) async {
    final limits = _shareCaptureLimits;

    try {
      _setCaptureProgress('正在截取长图…');
      final strips = await _captureFullCardScrollStrips();
      if (strips.isEmpty) return null;

      _setCaptureProgress('正在拼接…');

      ShareRgbaStrip stitched;
      if (_shareAdvancedExport) {
        final estimatedPhysicalHeight =
            (estimatedCapturePixels / physicalWidth).ceil();
        final composer = VerticalRgbaComposer.fromEstimatedPhysicalSize(
          estimatedPhysicalHeight: estimatedPhysicalHeight,
        );
        for (final strip in strips) {
          composer.appendStrip(strip);
        }
        stitched = composer.build();
      } else {
        stitched = await stitchRgbaVerticallyAsync(strips);
      }

      var stitchedSize = shareCaptureSizeFromPhysical(
        physicalWidth: stitched.width,
        physicalHeight: stitched.height,
        maxPixels: limits.maxPixels,
      );
      _rememberCaptureSize(stitchedSize);

      if (exceedsShareCaptureHardCap(
        estimatedCapturePixels: stitchedSize.totalPixels,
        advanced: _shareAdvancedExport,
        limits: limits,
      )) {
        if (_shareAdvancedExport) {
          stitched = await scaleRgbaStripToFitPixelsAsync(
            stitched,
            maxPixels: limits.maxPixels,
          );
          stitchedSize = shareCaptureSizeFromPhysical(
            physicalWidth: stitched.width,
            physicalHeight: stitched.height,
            maxPixels: limits.maxPixels,
          );
          _rememberCaptureSize(stitchedSize);
          _scaleExportNotice = formatScaledExportNotice(stitchedSize);
        } else {
          _showHeightCapError(stitchedSize);
          return null;
        }
      }

      return await _encodeFromRgba(stitched);
    } on Object catch (e, st) {
      talker.handle(e, st, 'Share chunked capture failed');
      _showCaptureFailure('生成图片失败，请稍后重试');
      return null;
    }
  }

  Future<_EncodedShareImage> _encodeFromRgba(ShareRgbaStrip strip) {
    switch (_shareImageFormat) {
      case ShareImageFormat.png:
        return _encodePngFromRgba(strip);
      case ShareImageFormat.jpeg:
        return _encodeJpegFromRgba(strip);
      case ShareImageFormat.webp:
        return _encodeWebpFromRgba(strip);
    }
  }

  Future<_EncodedShareImage> _encodePngFromRgba(ShareRgbaStrip strip) async {
    final png = await encodePngFromRgbaStrip(strip);
    if (kIsWeb) {
      return _EncodedShareImage(png, ShareImageFormat.png);
    }

    final optimized = await encodeSharePngOptimized(png);
    return _EncodedShareImage(optimized ?? png, ShareImageFormat.png);
  }

  Future<_EncodedShareImage> _encodeJpegFromRgba(ShareRgbaStrip strip) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromStrip(strip);
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
      final png = await encodePngFromRgbaStrip(strip);
      return _EncodedShareImage(png, ShareImageFormat.png);
    }

    final png = await encodePngFromRgbaStrip(strip);
    final jpeg = await encodeShareJpegFromPng(png);
    if (jpeg != null) {
      return _EncodedShareImage(jpeg, ShareImageFormat.jpeg);
    }

    final optimized = await encodeSharePngOptimized(png);
    return _EncodedShareImage(optimized ?? png, ShareImageFormat.png);
  }

  Future<_EncodedShareImage> _encodeWebpFromRgba(ShareRgbaStrip strip) async {
    if (kIsWeb) {
      final opaque = await _opaqueRgbaFromStrip(strip);
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
      final png = await encodePngFromRgbaStrip(strip);
      return _EncodedShareImage(png, ShareImageFormat.png);
    }

    final png = await encodePngFromRgbaStrip(strip);
    final webp = await encodeShareWebpFromPng(png);
    if (webp != null) {
      return _EncodedShareImage(webp, ShareImageFormat.webp);
    }

    final optimized = await encodeSharePngOptimized(png);
    return _EncodedShareImage(optimized ?? png, ShareImageFormat.png);
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

  Future<({Uint8List bytes, int width, int height})> _opaqueRgbaFromStrip(
    ShareRgbaStrip strip,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final card = S1Surface.card(scheme);
    final bgR = (card.r * 255).round();
    final bgG = (card.g * 255).round();
    final bgB = (card.b * 255).round();
    final expected = strip.width * strip.height * 4;
    final rgbaBytes = strip.bytes.length == expected
        ? strip.bytes
        : Uint8List.sublistView(strip.bytes, 0, expected);

    final opaque = await flattenRgbaOntoOpaqueRgbaAsync(
      rgba: rgbaBytes,
      width: strip.width,
      height: strip.height,
      bgR: bgR,
      bgG: bgG,
      bgB: bgB,
    );
    return (bytes: opaque, width: strip.width, height: strip.height);
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
    final title =
        widget.floors.length > 1 ? '分享 ${widget.floors.length} 个楼层' : '分享帖子';
    final showLogo = ref.watch(settingsProvider.select((s) => s.shareShowLogo));
    final showQr = ref.watch(settingsProvider.select((s) => s.shareShowQr));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SafeArea(
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
                          tid: widget.tid,
                          showLogo: showLogo,
                          showQr: showQr,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: S1Motion.short,
                  child: _buildFooter(scheme, textTheme, showLogo, showQr),
                ),
              ],
            ),
          ),
        ),
        if (_offscreenFullCardCapture)
          Positioned(
            left: -30000,
            top: 0,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
                devicePixelRatio: _sharePixelRatio,
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: ShareCard.shareTextTheme(
                    Theme.of(context).textTheme,
                  ),
                ),
                child: RepaintBoundary(
                  key: _offscreenCaptureKey,
                  child: ColoredBox(
                    color: S1Surface.card(scheme),
                    child: SizedBox(
                      width: ShareCard.cardWidth,
                      height: shareInFloorChunkLogicalSliceHeight(
                        _sharePixelRatio,
                        limits: _shareCaptureLimits,
                      ).toDouble(),
                      child: SingleChildScrollView(
                        controller: _offscreenScrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: ShareCard.cardWidth,
                          child: ShareCard(
                            floors: widget.floors,
                            threadSubject: widget.threadSubject,
                            poll: widget.poll,
                            tid: widget.tid,
                            showLogo: showLogo,
                            showQr: showQr,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(
    ColorScheme scheme,
    TextTheme textTheme,
    bool showLogo,
    bool showQr,
  ) {
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
        _FooterState.idle => _buildIdle(scheme, textTheme, showLogo, showQr),
        _FooterState.capturing => _buildCapturing(scheme, textTheme),
        _FooterState.error => _buildError(scheme, textTheme),
      },
    );
  }

  Widget _buildIdle(
    ColorScheme scheme,
    TextTheme textTheme,
    bool showLogo,
    bool showQr,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              avatar: const Icon(Icons.image_outlined, size: 16),
              label: const Text('Logo'),
              selected: showLogo,
              showCheckmark: false,
              onSelected: (value) {
                S1Haptics.selection();
                ref.read(settingsProvider.notifier).setShareShowLogo(value);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.qr_code_2, size: 16),
              label: const Text('二维码'),
              selected: showQr,
              showCheckmark: false,
              onSelected: (value) {
                S1Haptics.selection();
                ref.read(settingsProvider.notifier).setShareShowQr(value);
              },
            ),
          ],
        ),
        if (showQr) ...[
          const SizedBox(height: 8),
          Text(
            '部分平台会对带码图片限流',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildActions(),
      ],
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
            _captureProgressMessage.isEmpty
                ? '正在生成图片...'
                : _captureProgressMessage,
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
