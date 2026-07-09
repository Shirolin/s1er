import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../config/resource_domains.dart';
import '../widgets/web_image_stub.dart'
    if (dart.library.html) '../widgets/web_image_html.dart';

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.imageBytes,
    this.resourceType = ResourceType.publicAsset,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final ResourceType resourceType;

  String get _fileName {
    final uri = Uri.parse(imageUrl);
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image';
    return name.contains('.') ? name : '$name.jpg';
  }

  Future<void> _downloadImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (kIsWeb) {
        downloadImageWeb(imageUrl, _fileName);
        messenger.showSnackBar(
          const SnackBar(content: Text('下载已开始')),
        );
      } else if (imageBytes != null) {
        await Gal.putImageBytes(imageBytes!, name: _fileName);
        messenger.showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      } else {
        await Gal.putImage(imageUrl);
        messenger.showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('下载失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = imageBytes != null
        ? MemoryImage(imageBytes!) as ImageProvider
        : NetworkImage(imageUrl);

    return Scaffold(
      backgroundColor: colorScheme.inverseSurface,
      appBar: AppBar(
        backgroundColor: colorScheme.inverseSurface.withValues(alpha: 0.5),
        elevation: 0,
        foregroundColor: colorScheme.onInverseSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '下载图片',
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: resourceType == ResourceType.publicAsset && kIsWeb
              ? buildWebImage(imageUrl, width: 800, height: 800)
              : Image(image: provider),
        ),
      ),
    );
  }
}
