import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:share_plus/share_plus.dart';

import '../models/share_save_mode.dart';
import '../providers/settings_provider.dart';
import '../theme/s1_haptics.dart';
import '../widgets/s1_adaptive_sheet.dart';
import '../widgets/web_image_stub.dart'
    if (dart.library.html) '../widgets/web_image_html.dart';
import 'gallery_image_saver.dart';
import 's1_snack_bar.dart';

/// Linux 缺乏系统相册/文件分享通道，下载与分享项隐藏。
/// Web 走浏览器下载与 Web Share API（share_plus 自动降级为下载）。
bool get canDownloadImageOnPlatform => kIsWeb || !Platform.isLinux;

/// share_plus 不支持 Linux 文件分享。
bool get canShareImageOnPlatform => kIsWeb || !Platform.isLinux;

/// pasteboard 不支持 Linux 写图片，复制图片项隐藏。
bool get canCopyImageOnPlatform => kIsWeb || !Platform.isLinux;

/// 长按图片操作菜单的数据源，预览与内嵌两种模式共用。
class ImageActionsSpec {
  const ImageActionsSpec({
    required this.fullUrl,
    required this.fileName,
    this.bytes,
    this.fetchBytes,
    this.imageWidth,
    this.imageHeight,
  });

  /// 原图直链（复制链接用）。
  final String fullUrl;

  /// 下载 / 分享的文件名。
  final String fileName;

  /// 已持有的图片字节；为空时经 [fetchBytes] 拉取原图。
  final Uint8List? bytes;

  /// 异步拉取原图字节（[bytes] 为空时使用）。
  final Future<Uint8List?> Function()? fetchBytes;

  /// 图片像素宽（可选，用于信息弹窗）。
  final int? imageWidth;

  /// 图片像素高（可选，用于信息弹窗）。
  final int? imageHeight;
}

/// 保存管线的可注入签名（测试替换用）。
typedef ImageBytesSaver = Future<SaveImageResultStatus> Function({
  required Uint8List bytes,
  required String fileName,
  String? customDirectory,
  ShareSaveMode saveMode,
});

/// 系统分享的可注入签名（测试替换用）。
typedef ImageShareFn = Future<ShareResult> Function(ShareParams params);

/// 写图片到系统剪贴板的可注入签名（测试替换用）。
typedef ImageBytesCopier = Future<void> Function(Uint8List bytes);

/// 分享前的延迟（测试替换用）。
typedef ShareDelay = Future<void> Function();

/// Windows `DataTransferManager.ShowShareUI` 要求应用窗口在前台；菜单
/// 关闭动画期间立即调用会失败并提示「无法显示所有共享方法」。等待窗口
/// 恢复前台后再弹分享面板。
const Duration windowsShareActivationDelay = Duration(milliseconds: 350);

/// 从 URL 提取带扩展名的文件名。
String fileNameFromUrl(String url) {
  final uri = Uri.parse(url);
  final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image';
  return name.contains('.') ? name : '$name.jpg';
}

/// 由字节嗅探 + 文件名推断格式标签。
String imageFormatFor(String fileName, Uint8List? bytes) {
  if (bytes != null) {
    if (isWebpImageBytes(bytes)) return 'WebP';
    if (isPngImageBytes(bytes)) return 'PNG';
    if (isJpegImageBytes(bytes)) return 'JPEG';
  }
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'PNG';
  if (lower.endsWith('.gif')) return 'GIF';
  if (lower.endsWith('.webp')) return 'WebP';
  if (lower.endsWith('.bmp')) return 'BMP';
  return 'JPEG';
}

/// MIME 类型（分享用）：先嗅探字节，再按扩展名兜底。
String mimeTypeForImage({required Uint8List bytes, required String fileName}) {
  if (isWebpImageBytes(bytes)) return 'image/webp';
  if (isPngImageBytes(bytes)) return 'image/png';
  if (isJpegImageBytes(bytes)) return 'image/jpeg';
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.png')) return 'image/png';
  return 'image/jpeg';
}

String formatBytesSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 长按图片（桌面右键）弹出的操作菜单。
///
/// [canDownload] / [canShare] / [canCopyImage] 仅在需要覆盖平台默认判定时
/// 传入（测试模拟 Linux）。
Future<void> showImageActions(
  BuildContext context,
  ImageActionsSpec spec, {
  bool? canDownload,
  bool? canShare,
  bool? canCopyImage,
}) {
  final downloadVisible = canDownload ?? canDownloadImageOnPlatform;
  final shareVisible = canShare ?? canShareImageOnPlatform;
  final copyImageVisible = canCopyImage ?? canCopyImageOnPlatform;
  return showS1ActionSheet<void>(
    context: context,
    builder: (sheetContext) {
      return S1AdaptiveSheetScaffold(
        children: [
          if (downloadVisible)
            S1AdaptiveActionTile(
              icon: Icons.download_outlined,
              label: '下载',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(downloadImageBytes(context, spec));
              },
            ),
          if (shareVisible)
            S1AdaptiveActionTile(
              icon: Icons.share_outlined,
              label: '分享',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(shareImageBytes(context, spec));
              },
            ),
          if (copyImageVisible)
            S1AdaptiveActionTile(
              icon: Icons.copy_outlined,
              label: '复制图片',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(copyImageBytes(context, spec));
              },
            ),
          S1AdaptiveActionTile(
            icon: Icons.link_outlined,
            label: '复制链接',
            onTap: () {
              Navigator.of(sheetContext).pop();
              unawaited(copyImageLink(context, spec.fullUrl));
            },
          ),
          S1AdaptiveActionTile(
            icon: Icons.info_outline,
            label: '图片信息',
            onTap: () {
              Navigator.of(sheetContext).pop();
              unawaited(showImageInfoSheet(context, spec));
            },
          ),
        ],
      );
    },
  );
}

/// 下载 / 保存图片到相册或自定义目录（Web 触发浏览器下载）。
Future<void> downloadImageBytes(
  BuildContext context,
  ImageActionsSpec spec, {
  ImageBytesSaver saver = saveImageBytesToGallery,
}) async {
  try {
    final bytes = spec.bytes ?? await spec.fetchBytes?.call();
    if (bytes == null) {
      if (!context.mounted) return;
      S1SnackBar.error(context, message: '无法获取图片数据', bottomClearance: 16);
      return;
    }

    if (kIsWeb) {
      await downloadImageWeb(bytes, spec.fileName);
      if (!context.mounted) return;
      S1SnackBar.success(context, message: '下载已开始', bottomClearance: 16);
      return;
    }

    if (!context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final settings = container.read(settingsProvider);
    final result = await saver(
      bytes: bytes,
      fileName: spec.fileName,
      customDirectory: settings.customExportPath,
      saveMode: settings.shareSaveMode,
    );
    if (!context.mounted) return;

    final message = switch (result) {
      SaveImageResultStatus.cancelled => null,
      SaveImageResultStatus.fallbackSuccess => '原目录不可用，已自动保存至系统图片文件夹',
      SaveImageResultStatus.success => (settings.customExportPath != null &&
              settings.customExportPath!.isNotEmpty)
          ? '已保存至自定义目录'
          : '已保存到相册',
    };
    if (message != null) {
      S1SnackBar.success(context, message: message, bottomClearance: 16);
    }
  } on Object catch (e) {
    if (!context.mounted) return;
    S1SnackBar.error(context, message: '下载失败: $e', bottomClearance: 16);
  }
}

/// 通过系统分享面板分享图片字节。
Future<void> shareImageBytes(
  BuildContext context,
  ImageActionsSpec spec, {
  ImageShareFn share = _defaultShare,
  ShareDelay delay = _defaultShareDelay,
}) async {
  try {
    final origin = _shareOriginRect(context);
    await delay();
    final bytes = spec.bytes ?? await spec.fetchBytes?.call();
    if (bytes == null) {
      if (!context.mounted) return;
      S1SnackBar.error(context, message: '无法获取图片数据', bottomClearance: 16);
      return;
    }

    final fileName = spec.fileName;
    final result = await share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: mimeTypeForImage(bytes: bytes, fileName: fileName),
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        subject: fileName,
        sharePositionOrigin: origin,
      ),
    );
    if (!context.mounted) return;

    final toast = switch (result.status) {
      ShareResultStatus.success => '分享成功',
      ShareResultStatus.unavailable => '已打开分享',
      ShareResultStatus.dismissed => null,
    };
    if (toast != null) {
      S1SnackBar.success(context, message: toast, bottomClearance: 16);
    }
  } on Object {
    if (!context.mounted) return;
    S1SnackBar.error(context, message: '分享失败', bottomClearance: 16);
  }
}

Future<ShareResult> _defaultShare(ShareParams params) =>
    SharePlus.instance.share(params);

/// Windows 分享面板需要窗口已在前台；其它平台无延迟。
Future<void> _defaultShareDelay() {
  if (kIsWeb || !Platform.isWindows) return Future.value();
  return Future<void>.delayed(windowsShareActivationDelay);
}

/// 复制图片本身（非链接）到系统剪贴板。
Future<void> copyImageBytes(
  BuildContext context,
  ImageActionsSpec spec, {
  ImageBytesCopier copier = _defaultCopier,
}) async {
  try {
    final bytes = spec.bytes ?? await spec.fetchBytes?.call();
    if (bytes == null) {
      if (!context.mounted) return;
      S1SnackBar.error(context, message: '无法获取图片数据', bottomClearance: 16);
      return;
    }
    await copier(bytes);
    if (!context.mounted) return;
    S1Haptics.light();
    S1SnackBar.success(context, message: '已复制图片', bottomClearance: 16);
  } on Object {
    if (!context.mounted) return;
    S1SnackBar.error(context, message: '复制失败', bottomClearance: 16);
  }
}

Future<void> _defaultCopier(Uint8List bytes) => Pasteboard.writeImage(bytes);

/// 复制原图直链到剪贴板。
Future<void> copyImageLink(BuildContext context, String url) async {
  try {
    await Clipboard.setData(ClipboardData(text: url));
  } catch (_) {
    // 剪贴板在部分环境不可用。
  }
  if (!context.mounted) return;
  S1Haptics.light();
  S1SnackBar.show(context, message: '已复制图片链接', bottomClearance: 16);
}

/// 展示图片信息弹窗（文件名 / 格式 / 尺寸 / 大小）。
Future<void> showImageInfoSheet(BuildContext context, ImageActionsSpec spec) {
  return showS1InfoSheet<void>(
    context: context,
    builder: (_) => _ImageInfoSheet(spec: spec),
  );
}

/// iPad / macOS 分享面板的 popover 锚点。
Rect? _shareOriginRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ImageInfoSheet extends StatefulWidget {
  const _ImageInfoSheet({required this.spec});

  final ImageActionsSpec spec;

  @override
  State<_ImageInfoSheet> createState() => _ImageInfoSheetState();
}

class _ImageInfoSheetState extends State<_ImageInfoSheet> {
  Uint8List? _bytes;
  int? _width;
  int? _height;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final bytes = widget.spec.bytes ?? await widget.spec.fetchBytes?.call();
      var width = widget.spec.imageWidth;
      var height = widget.spec.imageHeight;
      if (bytes != null && (width == null || height == null)) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        width = frame.image.width;
        height = frame.image.height;
        frame.image.dispose();
        codec.dispose();
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _width = width;
        _height = height;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return S1AdaptiveSheetScaffold(
      title: '图片信息',
      children: [
        if (_loading)
          const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          _InfoRow(
            label: '文件名',
            value: widget.spec.fileName,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          _InfoRow(
            label: '格式',
            value: imageFormatFor(widget.spec.fileName, _bytes),
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          if (_width != null && _height != null)
            _InfoRow(
              label: '尺寸',
              value: '$_width × $_height px',
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          if (_bytes != null)
            _InfoRow(
              label: '大小',
              value: formatBytesSize(_bytes!.length),
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
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
