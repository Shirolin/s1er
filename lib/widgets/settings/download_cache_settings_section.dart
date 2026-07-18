import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../models/image_load_policy.dart';
import '../../providers/image_cache_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/s1_snack_bar.dart';
import '../s1_confirm_dialog.dart';
import 'settings_section_header.dart';

class DownloadCacheSettingsSection extends ConsumerStatefulWidget {
  const DownloadCacheSettingsSection({super.key});

  @override
  ConsumerState<DownloadCacheSettingsSection> createState() =>
      _DownloadCacheSettingsSectionState();
}

class _DownloadCacheSettingsSectionState
    extends ConsumerState<DownloadCacheSettingsSection> {
  bool _clearingImageCache = false;
  bool _sizeRequested = false;

  void _requestCacheSize() {
    setState(() => _sizeRequested = true);
    ref.invalidate(imageCacheSizeProvider);
  }

  Future<void> _clearImageCache() async {
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '清除图片缓存',
      content: kIsWeb
          ? '将清除应用内图片内存缓存。浏览器磁盘缓存由系统管理，可能无法完全清空。'
          : '将删除本地下载的图片缓存，下次浏览时会重新下载。',
      confirmLabel: '清除',
      destructive: true,
    );
    if (!confirmed || _clearingImageCache) return;

    setState(() => _clearingImageCache = true);
    try {
      await clearS1ImageCaches();
      if (_sizeRequested) {
        ref.invalidate(imageCacheSizeProvider);
      }
      if (mounted) {
        S1SnackBar.show(context, message: '已清除图片缓存');
      }
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '操作失败: $e');
      }
    } finally {
      if (mounted) setState(() => _clearingImageCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cacheSizeAsync =
        _sizeRequested ? ref.watch(imageCacheSizeProvider) : null;

    final cacheSummary = !_sizeRequested
        ? (kIsWeb ? '浏览器管理磁盘缓存；可清除应用内图片内存缓存' : '点击「查看占用」统计本地图片缓存')
        : cacheSizeAsync!.when(
            data: (bytes) {
              if (kIsWeb) {
                return '浏览器管理磁盘缓存；可清除应用内图片内存缓存';
              }
              return '当前约占用 ${formatImageCacheSize(bytes)}，上限 ${formatImageCacheSize(S1Constants.maxImageCacheBytes)}';
            },
            loading: () => '正在统计缓存占用…',
            error: (_, __) => '统计失败，请重试',
          );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '图片与缓存'),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.sd_storage_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('图片缓存占用'),
              subtitle: Text(
                cacheSummary,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: !_sizeRequested
                  ? TextButton(
                      onPressed: _requestCacheSize,
                      child: const Text('查看占用'),
                    )
                  : cacheSizeAsync?.isLoading == true
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('缓存上限', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    kIsWeb ? '仅移动端/桌面端：限制应用内图片内存缓存大小' : '限制应用内图片内存缓存大小',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: S1Constants.imageCacheLimitOptionsMb
                        .map(
                          (mb) => ButtonSegment(
                            value: mb,
                            label: Text('${mb}MB'),
                          ),
                        )
                        .toList(),
                    selected: {settings.imageCacheLimitMb},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      notifier.setImageCacheLimitMb(selection.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary:
                  Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
              title: const Text('显示图片'),
              subtitle: Text(
                '关闭后正文只显示图片占位，表情仍可见',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              value: settings.showImages,
              onChanged: notifier.setShowImages,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: settings.showImages ? 1 : S1Alpha.half,
              child: IgnorePointer(
                ignoring: !settings.showImages,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('正文图片加载', style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '全屏查看不受此限制；「手动」时点击加载单图',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ImageLoadPolicy>(
                        segments: const [
                          ButtonSegment(
                            value: ImageLoadPolicy.always,
                            label: Text('始终'),
                          ),
                          ButtonSegment(
                            value: ImageLoadPolicy.wifiOnly,
                            label: Text('仅 Wi-Fi'),
                          ),
                          ButtonSegment(
                            value: ImageLoadPolicy.manual,
                            label: Text('手动'),
                          ),
                        ],
                        selected: {settings.imageLoadPolicy},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          notifier.setImageLoadPolicy(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('头像加载', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '「手动」时点击加载单图',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ImageLoadPolicy>(
                    segments: const [
                      ButtonSegment(
                        value: ImageLoadPolicy.always,
                        label: Text('始终'),
                      ),
                      ButtonSegment(
                        value: ImageLoadPolicy.wifiOnly,
                        label: Text('仅 Wi-Fi'),
                      ),
                      ButtonSegment(
                        value: ImageLoadPolicy.manual,
                        label: Text('手动'),
                      ),
                    ],
                    selected: {settings.avatarLoadPolicy},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      notifier.setAvatarLoadPolicy(selection.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('每楼层最多显示图片', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '每个楼层/回复独立计数；0 表示不限制',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('不限')),
                      ButtonSegment(value: 5, label: Text('5')),
                      ButtonSegment(value: 10, label: Text('10')),
                      ButtonSegment(value: 20, label: Text('20')),
                      ButtonSegment(value: 50, label: Text('50')),
                    ],
                    selected: {settings.maxImagesPerPost},
                    // 五段已达紧凑屏横向上限；由容器色表达选中态，
                    // 避免默认勾号挤压两位数标签并触发换行。
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      notifier.setMaxImagesPerPost(selection.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.image_not_supported_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('清除图片缓存'),
              subtitle: Text(
                kIsWeb ? '清除应用内图片内存缓存' : '删除已下载的图片文件',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: _clearingImageCache
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _clearingImageCache
                  ? null
                  : () => unawaited(_clearImageCache()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
