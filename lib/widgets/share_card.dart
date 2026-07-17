import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/post.dart';
import '../providers/image_bytes_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/post_image_index_counter.dart';
import 'avatar_fallback.dart';
import 'bbcode_renderer.dart';
import 'force_show_images.dart';

/// A beautifully designed post card for sharing as an image.
///
/// Wraps content in [ForceShowImages] so all images render regardless of
/// user settings. The card is wrapped in a [RepaintBoundary]; pass a
/// [captureKey] to access the render object for image capture.
///
/// Avatars use [MemoryImage] (or letter fallback) — never [Image.network] —
/// so Web `RepaintBoundary.toImage` is not poisoned by failed network images.
class ShareCard extends StatelessWidget {
  ShareCard({
    super.key,
    required this.post,
    this.displayFloor,
    this.threadSubject,
    GlobalKey? captureKey,
  }) : _captureKey = captureKey ?? GlobalKey();

  /// Key for the outer [RepaintBoundary], used by the share sheet to capture
  /// the rendered card as an image.
  final GlobalKey _captureKey;

  final Post post;
  final int? displayFloor;
  final String? threadSubject;

  /// Fixed logical width at which the card is laid out. The captured image
  /// is rendered at the share-sheet's configured pixel ratio (default 2x)
  /// for excellent detail on high-DPI displays and social media platforms.
  static const double cardWidth = 750;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStr = formatDateTime(post.dateline);
    final floor = displayFloor ?? post.floor;
    final imageIndexCounter = PostImageIndexCounter();

    // Share cards are captured as fixed-layout images: ignore the user's
    // reading text scale so exported size stays consistent.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: RepaintBoundary(
        key: _captureKey,
        child: SizedBox(
          width: cardWidth,
          child: Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: const RoundedRectangleBorder(
              borderRadius: S1Shape.medium,
            ),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 6),
                  if (threadSubject != null && threadSubject!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        threadSubject!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  _buildAuthorRow(context, floor, timeStr),
                  const SizedBox(height: 16),
                  ForceShowImages(
                    enabled: true,
                    child: BbcodeRenderer(
                      bbcode: post.message,
                      imageIndexCounter: imageIndexCounter,
                      imagesExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.smartphone_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '来自 ${S1Constants.appName} 客户端',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          Icons.forum_outlined,
          size: 16,
          color: scheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          'Stage1st',
          style: textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Mirrors [PostItem] author header: avatar + name/time column, floor
  /// pinned to the trailing edge so the two-line block fills the row.
  Widget _buildAuthorRow(BuildContext context, int floor, String timeStr) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final letter = post.author.isNotEmpty ? post.author[0] : '?';

    return Row(
      children: [
        _ShareCaptureAvatar(
          url: post.avatar,
          radius: 20,
          fallbackLetter: letter,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          label: Text(
            '#$floor',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: scheme.secondaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ],
    );
  }
}

/// Capture-safe avatar: [MemoryImage] from Dio bytes, or letter fallback.
///
/// Avoids [Image.network] so a missing CDN avatar (404) cannot break
/// Web [RenderRepaintBoundary.toImage].
class _ShareCaptureAvatar extends ConsumerWidget {
  const _ShareCaptureAvatar({
    required this.url,
    required this.radius,
    required this.fallbackLetter,
  });

  final String? url;
  final double radius;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = url;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return AvatarFallbackLetter(radius: radius, letter: fallbackLetter);
    }

    final asyncBytes = ref.watch(imageBytesProvider(avatarUrl));
    return asyncBytes.when(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return AvatarFallbackLetter(radius: radius, letter: fallbackLetter);
        }
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      },
      loading: () => AvatarFallbackLetter(
        radius: radius,
        letter: fallbackLetter,
      ),
      error: (_, __) => AvatarFallbackLetter(
        radius: radius,
        letter: fallbackLetter,
      ),
    );
  }
}
