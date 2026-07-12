import 'dart:collection';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/resource_domains.dart';
import '../providers/connectivity_provider.dart';
import '../providers/settings_provider.dart';
import '../services/http_client.dart';
import '../services/s1_image_cache.dart';
import '../theme/app_theme.dart';
import '../utils/image_load_policy.dart';
import '../utils/inline_image_decode.dart';
import 'web_image_stub.dart'
    if (dart.library.html) 'web_image_html.dart';

class ImageViewer extends ConsumerStatefulWidget {

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.fullImageUrl,
    this.isEmoticon = false,
    this.showBorder = false,
    this.margin,
  });

  /// Inline preview URL.
  final String imageUrl;

  /// Full-size URL for the viewer screen; defaults to [imageUrl].
  final String? fullImageUrl;
  final bool isEmoticon;
  final bool showBorder;
  final EdgeInsetsGeometry? margin;

  /// Flush process-local byte LRU (called when clearing disk cache in settings).
  static void clearMemoryCache() {
    _ImageViewerState._cache.clear();
    _ImageViewerState._providerCache.clear();
    _ImageViewerState._cacheBytes = 0;
  }

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  /// 图片字节缓存（LRU），独立于 widget 生命周期；磁盘层见 [S1ImageCache]
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static final Map<String, MemoryImage> _providerCache = {};
  static const int _maxCacheEntries = 200;
  static const int _maxCacheBytes = 50 * 1024 * 1024;
  static int _cacheBytes = 0;

  bool _loading = false;
  bool _previewFailed = false;
  bool _userRequestedLoad = false;
  bool _deferredLoad = false;
  bool _networkLoadAllowed = false;
  Uint8List? _bytes;
  ImageProvider? _imageProvider;
  late ResourceType _resourceType;
  late String _displayUrl;
  double _webAspectRatio = 16 / 9;

  String get _previewUrl => widget.imageUrl;

  String get _fullUrl => widget.fullImageUrl ?? widget.imageUrl;

  bool get _hasDistinctFull => _previewUrl != _fullUrl;

  bool get _hasDisplayableImage =>
      _imageProvider != null ||
      (_resourceType == ResourceType.publicAsset && _networkLoadAllowed);

  @override
  void initState() {
    super.initState();
    _resourceType = _resolveType(_previewUrl);
    _displayUrl = _previewUrl;
    _load();
    _initDone = true;
  }

  @override
  void didUpdateWidget(ImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fullImageUrl != widget.fullImageUrl) {
      _resourceType = _resolveType(_previewUrl);
      _previewFailed = false;
      _userRequestedLoad = false;
      _deferredLoad = false;
      _networkLoadAllowed = false;
      _displayUrl = _previewUrl;
      _bytes = null;
      _imageProvider = null;
      _load();
    }
  }

  ResourceType _resolveType(String url) {
    final host = Uri.parse(url).host;
    return ResourceDomains.match(host)?.type ?? ResourceType.publicAsset;
  }

  bool _initDone = false;

  bool _shouldAutoLoad() {
    if (widget.isEmoticon) return true;
    final settings = ref.read(settingsProvider);
    final wifiConnected = ref.read(wifiConnectedProvider).value ?? true;
    return shouldAutoLoadInlineImages(
      showImages: settings.showImages,
      policy: settings.imageLoadPolicy,
      wifiConnected: wifiConnected,
      userRequested: _userRequestedLoad,
    );
  }

  void _load() {
    if (!widget.isEmoticon && !ref.read(settingsProvider).showImages) {
      return;
    }

    final url = _displayUrl;
    final cached = _cache[url];
    if (cached != null) {
      _cache.remove(url);
      _cache[url] = cached;
      _bytes = cached;
      _imageProvider = _providerCache[url];
      _loading = false;
      _deferredLoad = false;
      _networkLoadAllowed = true;
      if (_initDone) setState(() {});
      return;
    }

    _loadFromDiskOrNetwork(url);
  }

  Future<void> _loadFromDiskOrNetwork(String url) async {
    try {
      final disk = await S1ImageCache.getBytes(url);
      if (!mounted) return;
      if (disk != null) {
        _putInMemoryCache(url, disk);
        setState(() {
          _bytes = disk;
          _imageProvider = _providerCache[url];
          _loading = false;
          _deferredLoad = false;
          _networkLoadAllowed = true;
        });
        return;
      }
    } catch (_) {
      // Disk cache miss; continue to policy / network.
    }

    if (!mounted) return;
    if (!_shouldAutoLoad()) {
      setState(() {
        _loading = false;
        _deferredLoad = true;
        _networkLoadAllowed = false;
        _imageProvider = null;
      });
      return;
    }

    _deferredLoad = false;
    _networkLoadAllowed = true;
    if (_resourceType == ResourceType.publicAsset) {
      setState(() {
        _loading = false;
      });
      if (kIsWeb) {
        await _detectAspectRatio(url);
      }
      return;
    }

    await _loadAuthOrProxied(url);
  }

  void _requestManualLoad() {
    setState(() {
      _userRequestedLoad = true;
      _deferredLoad = false;
    });
    _load();
  }

  void _putInMemoryCache(String url, Uint8List data) {
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

  ImageProvider _publicNetworkProvider(String url) {
    return CachedNetworkImageProvider(
      url,
      cacheManager: S1ImageCache.manager,
    );
  }

  Future<void> _loadAuthOrProxied(String url) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _deferredLoad = false;
    });

    try {
      final httpClient = ref.read(httpClientProvider);
      final response = await httpClient.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      final data = response.data as Uint8List;

      _putInMemoryCache(url, data);
      await S1ImageCache.putBytes(url, data);

      if (!mounted) return;
      setState(() {
        _bytes = data;
        _imageProvider = _providerCache[url];
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (_shouldFallbackToFull(url, e)) {
        _fallbackToFullInline();
        return;
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  bool _shouldFallbackToFull(String url, DioException error) {
    if (_previewFailed || url != _previewUrl || !_hasDistinctFull) {
      return false;
    }
    final status = error.response?.statusCode;
    return status == null || status == 404;
  }

  void _fallbackToFullInline() {
    if (_previewFailed || !_hasDistinctFull || _displayUrl != _previewUrl) {
      return;
    }
    _previewFailed = true;
    setState(() {
      _displayUrl = _fullUrl;
      _resourceType = _resolveType(_fullUrl);
      _bytes = null;
      _imageProvider = null;
      _loading = false;
      _deferredLoad = false;
      _networkLoadAllowed = true;
    });
    _load();
  }

  void _handlePublicImageError() {
    _fallbackToFullInline();
  }

  Future<void> _detectAspectRatio(String url) async {
    final ratio = await detectImageAspectRatio(url);
    if (!mounted) return;
    if (ratio != _webAspectRatio) {
      setState(() {
        _webAspectRatio = ratio;
      });
    }
  }

  void _listenForPolicyChanges() {
    ref.listen(
      settingsProvider.select(
        (s) => (s.showImages, s.imageLoadPolicy),
      ),
      (previous, next) {
        if (widget.isEmoticon) return;
        if (!_deferredLoad && _hasDisplayableImage) return;
        if (_shouldAutoLoad()) {
          _load();
        }
      },
    );

    ref.listen(wifiConnectedProvider, (previous, next) {
      if (widget.isEmoticon) return;
      if (!_deferredLoad && _hasDisplayableImage) return;
      if (_shouldAutoLoad()) {
        _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showImages = widget.isEmoticon ||
        ref.watch(settingsProvider.select((s) => s.showImages));

    _listenForPolicyChanges();

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

    if (_deferredLoad) {
      return _buildTapToLoadPlaceholder();
    }

    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_resourceType == ResourceType.publicAsset && kIsWeb) {
      return _buildWebPublicImage(context);
    }

    if (_imageProvider != null) {
      return _buildImage(_imageProvider!);
    }

    if (_resourceType == ResourceType.publicAsset) {
      return _buildImage(_publicNetworkProvider(_displayUrl));
    }

    return _buildError();
  }

  Widget _buildWebPublicImage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child = Semantics(
      button: true,
      label: '查看大图',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.hasBoundedWidth ? constraints.maxWidth : 300.0;
          final h = w / _webAspectRatio;
          return Stack(
            children: [
              buildWebImage(_displayUrl, width: w, height: h),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _showFullScreen(context),
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.showBorder) {
      child = ClipRRect(
        borderRadius: S1Shape.small,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: S1Shape.small,
          ),
          child: child,
        ),
      );
    }

    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }

    return child;
  }

  Widget _buildImage(ImageProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget child = Semantics(
      button: true,
      label: '查看大图',
      child: GestureDetector(
        onTap: () => _showFullScreen(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layoutWidth =
                constraints.hasBoundedWidth ? constraints.maxWidth : 300.0;
            final decodeWidth = inlineDecodeWidthPx(layoutWidth, dpr);
            final imageProvider = inlineImageProvider(provider, decodeWidth);

            return Image(
              key: ValueKey('$_displayUrl-$decodeWidth'),
              image: imageProvider,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null) {
                  S1ImageCache.evictIfNeeded();
                }
                if (wasSynchronouslyLoaded) return child;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (frame == null)
                      const SizedBox(
                        height: 96,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: frame != null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: child,
                    ),
                  ],
                );
              },
              errorBuilder: (_, __, ___) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _handlePublicImageError();
                });
                return _buildError();
              },
            );
          },
        ),
      ),
    );

    if (widget.showBorder) {
      child = ClipRRect(
        borderRadius: S1Shape.small,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: S1Shape.small,
          ),
          child: child,
        ),
      );
    }

    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }

    return child;
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

  Widget _buildTapToLoadPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget child = Semantics(
      button: true,
      label: '点击加载图片',
      child: GestureDetector(
        onTap: _requestManualLoad,
        child: Container(
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: S1Shape.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '点击加载图片',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }

    return child;
  }

  Widget _buildError() {
    return Semantics(
      button: true,
      label: '重试加载图片',
      child: GestureDetector(
        onTap: () {
          _userRequestedLoad = true;
          _loadAuthOrProxied(_displayUrl);
        },
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
    Widget child;
    if (_resourceType == ResourceType.publicAsset && kIsWeb) {
      child = buildWebImage(widget.imageUrl, width: size, height: size);
    } else {
      child = Image(
        key: ValueKey(widget.imageUrl),
        image: _imageProvider ?? _publicNetworkProvider(widget.imageUrl),
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox(width: size, height: size),
      );
    }

    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }

    return child;
  }

  void _showFullScreen(BuildContext context) {
    final previewBytes =
        !_hasDistinctFull || _displayUrl == _previewUrl ? _bytes : null;
    final fullType = _resolveType(_fullUrl);
    final query = StringBuffer(
      '/image-viewer?url=${Uri.encodeComponent(_previewUrl)}'
      '&fullUrl=${Uri.encodeComponent(_fullUrl)}'
      '&type=${fullType.name}',
    );
    context.push(
      query.toString(),
      extra: {
        'imageUrl': _fullUrl,
        'imageBytes': previewBytes,
        'resourceType': fullType,
      },
    );
  }
}
