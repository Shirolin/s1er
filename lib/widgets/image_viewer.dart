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
import '../providers/image_bytes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/image_cache_provider.dart';
import '../theme/app_theme.dart';
import '../utils/image_load_policy.dart';
import '../utils/inline_image_decode.dart';
import 'lazy_visibility_loader.dart';
import 'force_show_images.dart';

class ImageViewer extends ConsumerStatefulWidget {
  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.fullImageUrl,
    this.isEmoticon = false,
    this.showBorder = false,
    this.margin,
    this.deferUntilVisible = false,
  });

  /// Inline preview URL.
  final String imageUrl;

  /// Full-size URL for the viewer screen; defaults to [imageUrl].
  final String? fullImageUrl;
  final bool isEmoticon;
  final bool showBorder;
  final EdgeInsetsGeometry? margin;

  /// 为 true 时等到进入视口后再加载（帖子内联图片用）。
  final bool deferUntilVisible;

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
  bool _visibilityLoadTriggered = false;
  Uint8List? _bytes;
  ImageProvider? _imageProvider;
  late ResourceType _resourceType;
  late String _displayUrl;

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
    if (!widget.deferUntilVisible || widget.isEmoticon) {
      _load();
    }
    _initDone = true;
  }

  void _onBecomeVisible() {
    if (_visibilityLoadTriggered) return;
    _visibilityLoadTriggered = true;
    _load();
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
      _visibilityLoadTriggered = false;
      _displayUrl = _previewUrl;
      _bytes = null;
      _imageProvider = null;
      if (!widget.deferUntilVisible || widget.isEmoticon) {
        _load();
      }
    }
  }

  ResourceType _resolveType(String url) {
    final host = Uri.parse(url).host;
    return ResourceDomains.match(host)?.type ?? ResourceType.publicAsset;
  }

  bool _initDone = false;

  bool _shouldAutoLoad() {
    if (widget.isEmoticon) return true;
    if (ForceShowImages.read(context)) return true;
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
    if (!widget.isEmoticon &&
        !ForceShowImages.read(context) &&
        !ref.read(settingsProvider).showImages) {
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
      final disk = await getCachedImageBytes(url);
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
    } on Object {
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
    if (_resourceType == ResourceType.publicAsset && !kIsWeb) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // Web 上所有图片都通过统一代理取 bytes，再由 Flutter Image 渲染。
    // 避免 HtmlElementView 在 ListView 回收期间触发 detached RenderObject
    // 的 PlatformView post-frame 断言。
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
      cacheManager: s1ImageCacheManager,
    );
  }

  Future<void> _loadAuthOrProxied(String url) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _deferredLoad = false;
    });

    try {
      final data = await ref.read(imageBytesProvider(url).future);
      if (!mounted) return;
      if (data == null) {
        // 404 / empty: try full URL once for distinct preview→full pairs.
        if (_shouldTryFullOnMissing(url)) {
          _fallbackToFullInline();
          return;
        }
        setState(() => _loading = false);
        return;
      }

      _putInMemoryCache(url, data);
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
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  bool _shouldTryFullOnMissing(String url) {
    if (_previewFailed || url != _previewUrl || !_hasDistinctFull) {
      return false;
    }
    return true;
  }

  bool _shouldFallbackToFull(String url, DioException error) {
    if (!_shouldTryFullOnMissing(url)) return false;
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

  void _listenForPolicyChanges() {
    ref.listen(
      settingsProvider.select(
        (s) => (s.showImages, s.imageLoadPolicy),
      ),
      (previous, next) {
        if (widget.isEmoticon) return;
        if (ForceShowImages.read(context)) return;
        if (widget.deferUntilVisible && !_visibilityLoadTriggered) return;
        if (!_deferredLoad && _hasDisplayableImage) return;
        if (_shouldAutoLoad()) {
          _load();
        }
      },
    );

    ref.listen(wifiConnectedProvider, (previous, next) {
      if (widget.isEmoticon) return;
      if (widget.deferUntilVisible && !_visibilityLoadTriggered) return;
      if (!_deferredLoad && _hasDisplayableImage) return;
      if (_shouldAutoLoad()) {
        _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showImages = widget.isEmoticon ||
        ForceShowImages.of(context) ||
        ref.watch(settingsProvider.select((s) => s.showImages));

    _listenForPolicyChanges();

    ref.listen<bool>(
      settingsProvider.select((s) => s.showImages),
      (previous, next) {
        if (!widget.isEmoticon && next && previous == false) {
          if (widget.deferUntilVisible && !_visibilityLoadTriggered) return;
          _load();
        }
      },
    );

    if (!showImages) {
      return _wrapDeferred(_wrapBlockImage(_buildHiddenPlaceholder()));
    }

    if (widget.deferUntilVisible &&
        !widget.isEmoticon &&
        !_visibilityLoadTriggered &&
        !_hasDisplayableImage &&
        !_loading &&
        !_deferredLoad) {
      return _wrapDeferred(
        _wrapBlockImage(_blockPlaceholder(height: 96)),
      );
    }

    if (widget.isEmoticon) return _wrapDeferred(_buildEmoticon(context));

    if (_deferredLoad) {
      return _wrapDeferred(_wrapBlockImage(_buildTapToLoadPlaceholder()));
    }

    if (_loading) {
      return _wrapDeferred(
        _wrapBlockImage(
          _blockPlaceholder(
            height: 96,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_imageProvider != null) {
      return _wrapDeferred(_wrapBlockImage(_buildImage(_imageProvider!)));
    }

    if (_resourceType == ResourceType.publicAsset) {
      return _wrapDeferred(
        _wrapBlockImage(_buildImage(_publicNetworkProvider(_displayUrl))),
      );
    }

    return _wrapDeferred(_wrapBlockImage(_buildError()));
  }

  Widget _wrapDeferred(Widget child) {
    if (!widget.deferUntilVisible || widget.isEmoticon) return child;
    return LazyVisibilityLoader(
      onVisible: _onBecomeVisible,
      child: child,
    );
  }

  /// 帖内插图在内容栏内居中；表情保持行内。
  ///
  /// 宽图跟随父级内容栏（手机全宽 / PC [S1ContentWidth] reading）；
  /// 窄图按固有宽度居中。不再单独设图片 max——栏宽已由阅读布局约束。
  Widget _wrapBlockImage(Widget child) {
    if (widget.isEmoticon) return child;

    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : 300.0;
        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }

  Widget _blockPlaceholder({required double height, Widget? child}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: child,
    );
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

    return child;
  }

  Widget _buildHiddenPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
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

    return Semantics(
      button: true,
      label: '点击加载图片',
      child: GestureDetector(
        onTap: _requestManualLoad,
        child: Container(
          width: double.infinity,
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
          width: double.infinity,
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
    final provider = _imageProvider ??
        (!kIsWeb ? _publicNetworkProvider(widget.imageUrl) : null);
    Widget child = provider == null
        ? const SizedBox(width: size, height: size)
        : Image(
            key: ValueKey(widget.imageUrl),
            image: provider,
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                const SizedBox(width: size, height: size),
          );

    if (widget.margin != null) {
      child = Padding(padding: widget.margin!, child: child);
    }

    return child;
  }

  void _showFullScreen(BuildContext context) {
    // Only pass bytes when they already belong to the full URL.
    final imageBytes = (_displayUrl == _fullUrl) ? _bytes : null;
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
        'imageBytes': imageBytes,
        'resourceType': fullType,
      },
    );
  }
}
