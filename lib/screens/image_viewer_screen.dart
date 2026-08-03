import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/resource_domains.dart';
import '../providers/image_bytes_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/image_actions.dart';
import '../widgets/s1_click_region.dart';

enum _ViewerLoadState { loading, ready, error }

class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.imageBytes,
    this.resourceType = ResourceType.publicAsset,
  });

  final String imageUrl;
  final Uint8List? imageBytes;

  /// Kept for route compatibility; loading always goes through [imageBytesProvider].
  final ResourceType resourceType;

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  static const double _maxScale = 5.0;
  static const double _zoomStep = 1.5;

  final TransformationController _transformController =
      TransformationController();
  final ValueNotifier<String> _scaleLabel = ValueNotifier('100%');

  int? _width;
  int? _height;
  Uint8List? _fetchedBytes;
  MemoryImage? _cachedMemoryImage;
  _ViewerLoadState _loadState = _ViewerLoadState.loading;
  bool _downloading = false;
  bool _appliedInitialFit = false;
  double _currentScale = 1.0;
  double? _viewportWidth;
  double? _viewportHeight;

  bool get _canSaveToGallery => !kIsWeb && !Platform.isLinux;

  Uint8List? get _effectiveBytes => widget.imageBytes ?? _fetchedBytes;

  ImageProvider? get _imageProvider {
    final bytes = _effectiveBytes;
    if (bytes == null) return null;

    if (_cachedMemoryImage != null &&
        identical(_cachedMemoryImage!.bytes, bytes)) {
      return _cachedMemoryImage!;
    }

    _cachedMemoryImage = MemoryImage(bytes);
    return _cachedMemoryImage!;
  }

  double get _fitScale {
    final vw = _viewportWidth;
    final vh = _viewportHeight;
    final iw = _width;
    final ih = _height;
    if (vw == null || vh == null || iw == null || ih == null) return 1.0;
    if (iw <= 0 || ih <= 0 || vw <= 0 || vh <= 0) return 1.0;
    return math.min(vw / iw, vh / ih);
  }

  /// Allow zooming slightly below fit so large images can still reach「合适」.
  double get _minScale {
    final fit = _fitScale;
    return math.max(fit * 0.5, 0.01);
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _scaleLabel.dispose();
    super.dispose();
  }

  Future<void> _loadImage({bool isRetry = false}) async {
    if (isRetry) {
      if (!mounted) return;
      setState(() {
        _loadState = _ViewerLoadState.loading;
        _appliedInitialFit = false;
        _width = null;
        _height = null;
        if (widget.imageBytes == null) {
          _fetchedBytes = null;
          _cachedMemoryImage = null;
        }
      });
    }

    try {
      final bytes = widget.imageBytes ?? await _tryFetchBytes();
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _loadState = _ViewerLoadState.error);
        return;
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      if (!mounted) {
        frameInfo.image.dispose();
        codec.dispose();
        return;
      }

      setState(() {
        _width = frameInfo.image.width;
        _height = frameInfo.image.height;
        _fetchedBytes = bytes;
        _cachedMemoryImage = MemoryImage(bytes);
        _loadState = _ViewerLoadState.ready;
      });
      frameInfo.image.dispose();
      codec.dispose();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryApplyInitialFit();
      });
    } catch (e, st) {
      // Expected network/decode failures — local log only, never Sentry.
      debugPrint('load image for viewer: $e\n$st');
      if (mounted) {
        setState(() => _loadState = _ViewerLoadState.error);
      }
    }
  }

  Future<Uint8List?> _tryFetchBytes() async {
    return ref.read(imageBytesProvider(widget.imageUrl).future);
  }

  void _setScaleLabel(double scale) {
    _scaleLabel.value = '${(scale * 100).round()}%';
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      _currentScale = scale;
      _setScaleLabel(_currentScale);
    }
  }

  void _updateViewportSize(double width, double height) {
    if (_viewportWidth == width && _viewportHeight == height) return;
    _viewportWidth = width;
    _viewportHeight = height;
    if (!_appliedInitialFit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryApplyInitialFit();
      });
    }
  }

  void _tryApplyInitialFit() {
    if (_appliedInitialFit) return;
    if (_loadState != _ViewerLoadState.ready) return;
    if (_viewportWidth == null || _viewportHeight == null) return;
    if (_width == null || _height == null) return;
    _appliedInitialFit = true;
    _fitToScreen();
  }

  /// Scale relative to 1:1 (image pixel = logical pixel), centered in content area.
  void _applyScale(double newScale) {
    final viewportWidth = _viewportWidth;
    final viewportHeight = _viewportHeight;
    final imageWidth = _width;
    final imageHeight = _height;
    if (viewportWidth == null ||
        viewportHeight == null ||
        imageWidth == null ||
        imageHeight == null) {
      return;
    }

    final clampedScale = newScale.clamp(_minScale, _maxScale);
    final dx = (viewportWidth - imageWidth * clampedScale) / 2;
    final dy = (viewportHeight - imageHeight * clampedScale) / 2;

    final matrix = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(clampedScale, clampedScale, 1, 1);

    _transformController.value = matrix;
    setState(() {
      _currentScale = clampedScale;
      _setScaleLabel(_currentScale);
    });
  }

  void _fitToScreen() {
    if (_viewportWidth == null ||
        _viewportHeight == null ||
        _width == null ||
        _height == null) {
      return;
    }
    _applyScale(_fitScale);
  }

  void _zoomToActualSize() {
    _applyScale(1.0);
  }

  void _zoomIn() {
    _applyScale(_currentScale * _zoomStep);
  }

  void _zoomOut() {
    _applyScale(_currentScale / _zoomStep);
  }

  ImageActionsSpec get _actionsSpec => ImageActionsSpec(
        fullUrl: widget.imageUrl,
        fileName: fileNameFromUrl(widget.imageUrl),
        bytes: _effectiveBytes,
        fetchBytes: _tryFetchBytes,
        imageWidth: _width,
        imageHeight: _height,
      );

  void _showActions(BuildContext context) {
    showImageActions(context, _actionsSpec);
  }

  Future<void> _downloadImage() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await downloadImageBytes(context, _actionsSpec);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _buildViewerBody(ColorScheme colorScheme) {
    return switch (_loadState) {
      _ViewerLoadState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
      _ViewerLoadState.error => Center(
          child: Semantics(
            button: true,
            label: '重试加载图片',
            child: S1ClickRegion(
              onTap: () => _loadImage(isRetry: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onInverseSurface
                        .withValues(alpha: S1Alpha.viewerScrim),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '加载失败，点击重试',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onInverseSurface
                              .withValues(alpha: S1Alpha.viewerScrim),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      _ViewerLoadState.ready => LayoutBuilder(
          builder: (context, constraints) {
            _updateViewportSize(constraints.maxWidth, constraints.maxHeight);
            final provider = _imageProvider;
            final width = _width;
            final height = _height;
            if (provider == null || width == null || height == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () {
                S1Haptics.medium();
                _showActions(context);
              },
              onSecondaryTapDown: (_) => _showActions(context),
              child: InteractiveViewer(
                transformationController: _transformController,
                constrained: false,
                minScale: _minScale,
                maxScale: _maxScale,
                onInteractionUpdate: _onInteractionUpdate,
                child: SizedBox(
                  width: width.toDouble(),
                  height: height.toDouble(),
                  child: Image(
                    image: provider,
                    fit: BoxFit.fill,
                    width: width.toDouble(),
                    height: height.toDouble(),
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.onInverseSurface
                            .withValues(alpha: S1Alpha.viewerScrim),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    };
  }

  Widget _buildTopBar(ColorScheme colorScheme) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                color: colorScheme.onSurface,
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: '图片信息',
                color: colorScheme.onSurface,
                onPressed: () => showImageInfoSheet(context, _actionsSpec),
              ),
              if (kIsWeb || _canSaveToGallery)
                IconButton(
                  tooltip: kIsWeb ? '下载' : '保存到相册',
                  color: colorScheme.onSurface,
                  onPressed: _downloading ? null : _downloadImage,
                  icon: _downloading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSurface,
                          ),
                        )
                      : const Icon(Icons.download_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar(ColorScheme colorScheme, TextTheme textTheme) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final controlsEnabled = _loadState == _ViewerLoadState.ready;

    return Material(
      color: colorScheme.surfaceContainerHigh
          .withValues(alpha: S1Alpha.controlBar),
      borderRadius: BorderRadius.vertical(top: S1Shape.large.topLeft),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 4 + bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.fit_screen_outlined),
              tooltip: '合适',
              color: colorScheme.onSurface,
              onPressed: controlsEnabled ? _fitToScreen : null,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_outlined),
              tooltip: '缩小',
              color: colorScheme.onSurface,
              onPressed: controlsEnabled ? _zoomOut : null,
            ),
            SizedBox(
              width: 52,
              child: ValueListenableBuilder<String>(
                valueListenable: _scaleLabel,
                builder: (_, label, __) {
                  return Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in_outlined),
              tooltip: '放大',
              color: colorScheme.onSurface,
              onPressed: controlsEnabled ? _zoomIn : null,
            ),
            IconButton(
              // Text label — icon metaphors for 1:1 are obscure.
              icon: Text(
                '1:1',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              tooltip: '原始大小',
              onPressed: controlsEnabled ? _zoomToActualSize : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.scrim,
      body: Column(
        children: [
          _buildTopBar(colorScheme),
          Expanded(child: _buildViewerBody(colorScheme)),
          _buildControlBar(colorScheme, textTheme),
        ],
      ),
    );
  }
}
