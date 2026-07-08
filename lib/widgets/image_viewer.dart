import 'dart:collection';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/resource_domains.dart';
import '../services/http_client.dart';
import 'web_image_stub.dart'
    if (dart.library.html) 'web_image_html.dart';

class ImageViewer extends ConsumerStatefulWidget {

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.isEmoticon = false,
  });

  final String imageUrl;
  final bool isEmoticon;

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  /// 图片字节缓存（LRU），独立于 widget 生命周期
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static const int _maxCacheEntries = 200;

  bool _loading = false;
  Uint8List? _bytes;
  late ResourceType _resourceType;

  @override
  void initState() {
    super.initState();
    _resourceType = _resolveType();
    _load();
    _initDone = true;
  }

  @override
  void didUpdateWidget(ImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resourceType = _resolveType();
      _load();
    }
  }

  ResourceType _resolveType() {
    final host = Uri.parse(widget.imageUrl).host;
    return ResourceDomains.match(host)?.type ?? ResourceType.publicAsset;
  }

  bool _initDone = false;

  void _load() {
    final cached = _cache[widget.imageUrl];
    if (cached != null) {
      _cache.remove(widget.imageUrl);
      _cache[widget.imageUrl] = cached;
      _bytes = cached;
      _loading = false;
      // initState 中不需要 setState（build 还没调用），didUpdateWidget 中需要
      if (_initDone) setState(() {});
      return;
    }

    // 公开资源：Web 端用原生 <img>，Native 端用 NetworkImage，都不需要 Dio
    if (_resourceType == ResourceType.publicAsset) {
      _loading = false;
      return;
    }

    _loadViaDio();
  }

  Future<void> _loadViaDio() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      final httpClient = ref.read(httpClientProvider);
      final response = await httpClient.get(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      final data = response.data as Uint8List;

      // 写入 LRU 缓存
      _cache[widget.imageUrl] = data;
      if (_cache.length > _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }

      setState(() {
        _bytes = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmoticon) return _buildEmoticon(context);

    // Web 公开资源：原生 <img>，无 CORS
    if (_resourceType == ResourceType.publicAsset && kIsWeb) {
      return GestureDetector(
        onTap: () => _showFullScreen(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.hasBoundedWidth ? constraints.maxWidth : 300.0;
            return buildWebImage(widget.imageUrl, width: w, height: w);
          },
        ),
      );
    }

    // 有缓存字节 → 直接渲染
    if (_bytes != null) {
      return _buildImage(MemoryImage(_bytes!));
    }

    // Native 公开资源：NetworkImage
    if (_resourceType == ResourceType.publicAsset) {
      return _buildImage(NetworkImage(widget.imageUrl));
    }

    // 加载中
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // 错误
    return _buildError();
  }

  Widget _buildImage(ImageProvider provider) {
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (frame == null)
                const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              AnimatedOpacity(
                opacity: frame != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (_, __, ___) => _buildError(),
      ),
    );
  }

  Widget _buildError() {
    return GestureDetector(
      onTap: _loadViaDio,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Icon(Icons.broken_image_outlined, size: 24, color: Theme.of(context).colorScheme.outline)),
      ),
    );
  }

  Widget _buildEmoticon(BuildContext context) {
    const double size = 28.0;
    if (_resourceType == ResourceType.publicAsset && kIsWeb) {
      return buildWebImage(widget.imageUrl, width: size, height: size);
    }
    return Image(
      image: _bytes != null
          ? MemoryImage(_bytes!)
          : NetworkImage(widget.imageUrl),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(width: size, height: size),
    );
  }

  void _showFullScreen(BuildContext context) {
    final provider = _bytes != null
        ? MemoryImage(_bytes!) as ImageProvider
        : NetworkImage(widget.imageUrl);
    final colorScheme = Theme.of(context).colorScheme;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: colorScheme.inverseSurface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: colorScheme.onInverseSurface),
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: _resourceType == ResourceType.publicAsset && kIsWeb
                  ? buildWebImage(widget.imageUrl, width: 800, height: 800)
                  : Image(image: provider),
            ),
          ),
        ),
      ),
    );
  }
}
