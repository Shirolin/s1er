import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  final dynamic imageBytes;
  final ResourceType resourceType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = imageBytes != null
        ? MemoryImage(imageBytes) as ImageProvider
        : NetworkImage(imageUrl);

    return Scaffold(
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
          child: resourceType == ResourceType.publicAsset && kIsWeb
              ? buildWebImage(imageUrl, width: 800, height: 800)
              : Image(image: provider),
        ),
      ),
    );
  }
}
