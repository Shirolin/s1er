import 'dart:typed_data';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
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
        return;
      }

      Uint8List bytes;
      if (imageBytes != null) {
        bytes = imageBytes!;
      } else {
        final dio = Dio();
        final response = await dio.get<List<int>>(
          imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data!);
      }

      final tempDir = await getTemporaryDirectory();
      final ext = _fileName.contains('.') ? _fileName.split('.').last : 'jpg';
      final tempFile = File('${tempDir.path}/s1_download_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await tempFile.writeAsBytes(bytes);
      await Gal.putImage(tempFile.path);
      await tempFile.delete();

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final provider = imageBytes != null
        ? MemoryImage(imageBytes!) as ImageProvider
        : NetworkImage(imageUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '下载图片',
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: resourceType == ResourceType.publicAsset && kIsWeb
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return buildWebImage(
                      imageUrl,
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
}
