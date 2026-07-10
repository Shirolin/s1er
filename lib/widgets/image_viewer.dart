import 'dart:collection';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/resource_domains.dart';
import '../providers/settings_provider.dart';
import '../services/http_client.dart';
import '../theme/app_theme.dart';
import 'web_image_stub.dart'
    if (dart.library.html) 'web_image_html.dart';

class ImageViewer extends ConsumerStatefulWidget {

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.isEmoticon = false,
    this.showBorder = false,
    this.margin,
  });

  final String imageUrl;
  final bool isEmoticon;
  final bool showBorder;
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  /// 图片字节缓存（LRU），独立于 widget 生命周期
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static final Map<String, MemoryImage> _providerCache = {};
  static const int _maxCacheEntries = 200;
  static const int _maxCacheBytes = 50 * 1024 * 1024;
  static int _cacheBytes = 0;

  bool _loading = false;
  Uint8List? _bytes;
  ImageProvider? _imageProvider;
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
    if (!widget.isEmoticon && !ref.read(settingsProvider).showImages) {
      return;
    }

    final cached = _cache[widget.imageUrl];
    if (cached != null) {
      _cache.remove(widget.imageUrl);
      _cache[widget.imageUrl] = cached;
      _bytes = cached;
      _imageProvider = _providerCache[widget.imageUrl];
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

  void _putInCache(String url, Uint8List data) {
    if (_cache.containsKey(url)) {
      _cacheBytes -= _cache[url]!.length;
      _cache.remove(url);
      _providerCache.remove(url);
    }
    _cache[url] = data;
    _providerCache[url] = MemoryImage(data);
    _cacheBytes += data.length;

    while (_cache.length > _maxCacheEntries || _cacheBytes > _maxCacheBytes) {
      final evicted = _cache.keys.first;
      _cacheBytes -= _cache[evicted]!.length;
      _cache.remove(evicted);
      _providerCache.remove(evicted);
    }
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
      _putInCache(widget.imageUrl, data);

      setState(() {
        _bytes = data;
        _imageProvider = _providerCache[widget.imageUrl];
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
    final showImages = widget.isEmoticon ||
        ref.watch(settingsProvider.select((s) => s.showImages));

    ref.listen<bool>(
      settingsProvider.select((s) => s.showImages),
      (previous, next) {
        if (!widget.isEmoticon && next && previous == false) {
          _load();
        }
      },
    );

    if (!showImages) return _buildHiddenPlaceholder();

    if (widget.isEmoticon) return _buildEmoticon(context);

    // Web 公开资源：原生 <img>，无 CORS
    if (_resourceType == ResourceType.publicAsset && kIsWeb) {
      return Semantics(
        button: true,
        label: '查看大图',
        child: GestureDetector(
          onTap: () => _showFullScreen(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.hasBoundedWidth ? constraints.maxWidth : 300.0;
              return buildWebImage(widget.imageUrl, width: w, height: w);
            },
          ),
        ),
      );
    }

    // 有缓存字节 → 直接渲染（复用 ImageProvider，避免重复解码/释放 Picture）
    if (_imageProvider != null) {
      return _buildImage(_imageProvider!);
    }

    // Native 公开资源：NetworkImage
    if (_resourceType == ResourceType.publicAsset) {
      return _buildImage(NetworkImage(widget.imageUrl));
    }

    // 加载中
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // 错误
    return _buildError();
  }

  Widget _buildImage(ImageProvider provider) {
    return Semantics(
      button: true,
      label: '查看大图',
      child: GestureDetector(
        onTap: () => _showFullScreen(context),
        child: Image(
        key: ValueKey(widget.imageUrl),
        image: provider,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (frame == null)
                const SizedBox(
                  height: 96,
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
      ),
    );
  }

  Widget _buildHiddenPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: S1Shape.small,
      ),
      child: Text(
        '[图片]',
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildError() {
    return Semantics(
      button: true,
      label: '重试加载图片',
      child: GestureDetector(
        onTap: _loadViaDio,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: S1Shape.small,
          ),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmoticon(BuildContext context) {
    const double size = 24.0;
    if (_resourceType == ResourceType.publicAsset && kIsWeb) {
      return buildWebImage(widget.imageUrl, width: size, height: size);
    }
    return Image(
      key: ValueKey(widget.imageUrl),
      image: _imageProvider ?? NetworkImage(widget.imageUrl),
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox(width: size, height: size),
    );
  }

  void _showFullScreen(BuildContext context) {
    final encodedUrl = Uri.encodeComponent(widget.imageUrl);
    context.push(
      '/image-viewer?url=$encodedUrl&type=${_resourceType.name}',
      extra: {
        'imageUrl': widget.imageUrl,
        'imageBytes': _bytes,
        'resourceType': _resourceType,
      },
    );
  }
}
