import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../config/resource_domains.dart';
import '../services/http_client.dart';
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
  Uint8List? _fetchedBytes;
  bool _downloading = false;

  bool get _canSaveToGallery =>
      !kIsWeb && !Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (widget.imageBytes == null) {
      _tryFetchBytes().then((bytes) {
        if (bytes != null && mounted) {
          setState(() => _fetchedBytes = bytes);
        }
      });
    }
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

  Uint8List? get _effectiveBytes => widget.imageBytes ?? _fetchedBytes;

  Future<void> _downloadImage(BuildContext context) async {
    if (_downloading || !_canSaveToGallery) return;
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

      await Gal.putImageBytes(bytes, name: _fileName);

      if (context.mounted) {
        messenger.clearSnackBars();
        S1SnackBar.show(context, message: '已保存到相册', bottomClearance: 16);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = _effectiveBytes != null
        ? MemoryImage(_effectiveBytes!)
        : NetworkImage(widget.imageUrl) as ImageProvider;

    return Scaffold(
      backgroundColor: colorScheme.inverseSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colorScheme.onInverseSurface,
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: '下载',
              onPressed: () {
                downloadImageWeb(widget.imageUrl, _fileName);
                S1SnackBar.show(context, message: '下载已开始', bottomClearance: 16);
              },
              icon: const Icon(Icons.download_outlined),
            )
          else if (_canSaveToGallery)
            IconButton(
              tooltip: '保存到相册',
              onPressed: _downloading ? null : () => _downloadImage(context),
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: widget.resourceType == ResourceType.publicAsset && kIsWeb
              ? buildWebImage(widget.imageUrl, width: 800, height: 800)
              : Image(image: provider),
        ),
      ),
    );
  }
}
