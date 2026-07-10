import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../config/resource_domains.dart';
import '../widgets/web_image_stub.dart'
    if (dart.library.html) '../widgets/web_image_html.dart';

class ImageViewerScreen extends StatefulWidget {
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
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  int? _width;
  int? _height;
  Uint8List? _fetchedBytes;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _decodeDimensions();
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
      });
      frameInfo.image.dispose();
      codec.dispose();
    } catch (_) {}
  }

  Future<Uint8List?> _tryFetchBytes() async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
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

  Future<void> _downloadImage(BuildContext context) async {
    if (_downloading) return;
    setState(() => _downloading = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      if (kIsWeb) {
        downloadImageWeb(widget.imageUrl, _fileName);
        messenger.showSnackBar(
          const SnackBar(content: Text('下载已开始')),
        );
        return;
      }

      Uint8List bytes;
      if (_effectiveBytes != null) {
        bytes = _effectiveBytes!;
      } else {
        final dio = Dio();
        final response = await dio.get<List<int>>(
          widget.imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data!);
      }

      await Gal.putImageBytes(bytes, name: _fileName);

      if (context.mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final provider = widget.imageBytes != null
        ? MemoryImage(widget.imageBytes!) as ImageProvider
        : NetworkImage(widget.imageUrl);

    return Scaffold(
      backgroundColor: colorScheme.scrim,
      appBar: AppBar(
        backgroundColor: colorScheme.scrim.withValues(alpha: 0.5),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '图片信息',
            onPressed: () => _showInfoSheet(context),
          ),
          IconButton(
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: '下载图片',
            onPressed: _downloading ? null : () => _downloadImage(context),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: widget.resourceType == ResourceType.publicAsset && kIsWeb
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return buildWebImage(
                      widget.imageUrl,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    );
                  },
                )
              : Image(image: provider),
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                    borderRadius: BorderRadius.circular(2),
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
