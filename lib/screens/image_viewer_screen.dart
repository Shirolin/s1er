import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';

import '../config/resource_domains.dart';
import '../services/http_client.dart';
import '../theme/app_theme.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/web_image_stub.dart'
    if (dart.library.html) '../widgets/web_image_html.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.imageBytes,
    this.resourceType = ResourceType.publicAsset,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final ResourceType resourceType;

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;
  static const double _zoomStep = 1.5;

  final TransformationController _transformController =
      TransformationController();
  final ValueNotifier<String> _scaleLabel = ValueNotifier('100%');

  int? _width;
  int? _height;
  Uint8List? _fetchedBytes;
  MemoryImage? _cachedMemoryImage;
  bool _downloading = false;
  double _currentScale = 1.0;
  double? _viewportWidth;
  double? _viewportHeight;

  bool get _canSaveToGallery => !kIsWeb && !Platform.isLinux;

  ImageProvider _resolveProvider() {
    final bytes = widget.imageBytes ?? _fetchedBytes;
    if (bytes == null) return NetworkImage(widget.imageUrl);

    if (_cachedMemoryImage != null && identical(_cachedMemoryImage!.bytes, bytes)) {
      return _cachedMemoryImage!;
    }

    _cachedMemoryImage = MemoryImage(bytes);
    return _cachedMemoryImage!;
  }

  @override
  void initState() {
    super.initState();
    _decodeDimensions();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _scaleLabel.dispose();
    super.dispose();
  }

  Future<void> _decodeDimensions() async {
    final bytes = widget.imageBytes ?? await _tryFetchBytes();
    if (bytes == null || !mounted) return;

    try {
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
        _fetchedBytes ??= bytes;
        _cachedMemoryImage ??= MemoryImage(bytes);
      });
      frameInfo.image.dispose();
      codec.dispose();
    } catch (_) {}
  }

  Future<Uint8List?> _tryFetchBytes() async {
    try {
      final httpClient = ref.read(httpClientProvider);
      final response = await httpClient.get(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data as List<int>);
    } catch (_) {
      return null;
    }
  }

  String get _fileName {
    final uri = Uri.parse(widget.imageUrl);
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image';
    return name.contains('.') ? name : '$name.jpg';
  }

  String get _format {
    final lower = _fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'PNG';
    if (lower.endsWith('.gif')) return 'GIF';
    if (lower.endsWith('.webp')) return 'WebP';
    if (lower.endsWith('.bmp')) return 'BMP';
    return 'JPEG';
  }

  Uint8List? get _effectiveBytes => widget.imageBytes ?? _fetchedBytes;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      _currentScale = scale;
      _scaleLabel.value =
          '${(_currentScale * 100).round()}%';
    }
  }

  void _updateViewportSize(double width, double height) {
    if (_viewportWidth == width && _viewportHeight == height) return;
    _viewportWidth = width;
    _viewportHeight = height;
  }

  void _applyScale(double newScale) {
    final viewportWidth = _viewportWidth;
    final viewportHeight = _viewportHeight;
    if (viewportWidth == null || viewportHeight == null) return;

    final clampedScale = newScale.clamp(_minScale, _maxScale);
    final center = Offset(viewportWidth / 2, viewportHeight / 2);
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(clampedScale, clampedScale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    _transformController.value = matrix;
    setState(() {
      _currentScale = clampedScale;
      _scaleLabel.value = '${(_currentScale * 100).round()}%';
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
      _scaleLabel.value = '100%';
    });
  }

  void _fitToScreen() {
    final viewportWidth = _viewportWidth;
    final viewportHeight = _viewportHeight;
    if (viewportWidth == null ||
        viewportHeight == null ||
        _width == null ||
        _height == null) {
      _resetZoom();
      return;
    }

    final scaleX = viewportWidth / _width!;
    final scaleY = viewportHeight / _height!;
    _applyScale(math.min(scaleX, scaleY));
  }

  void _zoomTo100() {
    _applyScale(1.0);
  }

  void _zoomIn() {
    _applyScale(_currentScale * _zoomStep);
  }

  void _zoomOut() {
    _applyScale(_currentScale / _zoomStep);
  }

  Future<void> _downloadImage(BuildContext context) async {
    if (_downloading) return;
    if (!kIsWeb && !_canSaveToGallery) return;
    setState(() => _downloading = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      Uint8List bytes;
      if (_effectiveBytes != null) {
        bytes = _effectiveBytes!;
      } else {
        final fetched = await _tryFetchBytes();
        if (fetched == null) throw StateError('无法获取图片数据');
        bytes = fetched;
      }

      if (kIsWeb) {
        await downloadImageWeb(bytes, _fileName);
      } else {
        await Gal.putImageBytes(bytes, name: _fileName);
      }

      if (context.mounted) {
        messenger.clearSnackBars();
        S1SnackBar.show(
          context,
          message: kIsWeb ? '下载已开始' : '已保存到相册',
          bottomClearance: 16,
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.clearSnackBars();
        S1SnackBar.show(context, message: '下载失败: $e', bottomClearance: 16);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _buildImageContent(ImageProvider provider, ColorScheme colorScheme) {
    if (widget.resourceType == ResourceType.publicAsset && kIsWeb) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _updateViewportSize(constraints.maxWidth, constraints.maxHeight);
          return buildWebImage(
            widget.imageUrl,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _updateViewportSize(constraints.maxWidth, constraints.maxHeight);
        return Image(
          image: provider,
          fit: BoxFit.contain,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: colorScheme.onInverseSurface.withValues(alpha: 0.54),
              size: 48,
            ),
          ),
        );
      },
    );
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
                onPressed: () => _showInfoSheet(context),
              ),
              if (kIsWeb || _canSaveToGallery)
                IconButton(
                  tooltip: kIsWeb ? '下载' : '保存到相册',
                  color: colorScheme.onSurface,
                  onPressed: _downloading ? null : () => _downloadImage(context),
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
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
              onPressed: _fitToScreen,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_outlined),
              tooltip: '缩小',
              color: colorScheme.onSurface,
              onPressed: _zoomOut,
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
              onPressed: _zoomIn,
            ),
            IconButton(
              icon: const Icon(Icons.filter_1_outlined),
              tooltip: '100%',
              color: colorScheme.onSurface,
              onPressed: _zoomTo100,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt_outlined),
              tooltip: '重置',
              color: colorScheme.onSurface,
              onPressed: _resetZoom,
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
    final provider = _resolveProvider();

    return Scaffold(
      backgroundColor: colorScheme.scrim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transformController,
            minScale: _minScale,
            maxScale: _maxScale,
            onInteractionUpdate: _onInteractionUpdate,
            child: _buildImageContent(provider, colorScheme),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(colorScheme),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControlBar(colorScheme, textTheme),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: S1Shape.bottomSheetShape,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: S1Shape.extraSmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('图片信息', style: textTheme.titleMedium),
              const SizedBox(height: 16),
              _infoRow('文件名', _fileName, textTheme, colorScheme),
              _infoRow('格式', _format, textTheme, colorScheme),
              if (_width != null && _height != null)
                _infoRow('尺寸', '$_width × $_height px', textTheme, colorScheme),
              if (_effectiveBytes != null)
                _infoRow('大小', _formatSize(_effectiveBytes!.length), textTheme, colorScheme),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, TextTheme textTheme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
