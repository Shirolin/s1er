import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/poll.dart';
import '../models/post.dart';
import '../models/share_floor_data.dart';
import '../providers/image_bytes_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/poll_bar_color.dart';
import '../utils/post_image_index_counter.dart';
import 'avatar_fallback.dart';
import 'bbcode_renderer.dart';
import 'force_show_images.dart';

/// Keys for full-card vs per-section capture (chunked stitch path).
class ShareCaptureKeys {
  ShareCaptureKeys({required int floorCount})
      : full = GlobalKey(),
        header = GlobalKey(),
        floors = List<GlobalKey>.generate(floorCount, (_) => GlobalKey()),
        footer = GlobalKey();

  final GlobalKey full;
  final GlobalKey header;
  final List<GlobalKey> floors;
  final GlobalKey footer;
}

/// Designed post card for sharing as an image (one or more floors).
///
/// Wraps content in [ForceShowImages]. Pass [captureKeys] for chunked capture,
/// or a lone [captureKey] / default key on the outer [RepaintBoundary].
class ShareCard extends StatelessWidget {
  ShareCard({
    super.key,
    required this.floors,
    this.threadSubject,
    this.poll,
    this.captureKeys,
    GlobalKey? captureKey,
  })  : assert(floors.isNotEmpty, 'ShareCard requires at least one floor'),
        _fallbackFullKey = captureKey ?? GlobalKey();

  /// Single-floor convenience (existing call sites / tests).
  ShareCard.single({
    super.key,
    required Post post,
    int? displayFloor,
    this.threadSubject,
    this.poll,
    this.captureKeys,
    GlobalKey? captureKey,
  })  : floors = [
          ShareFloorData(
            post: post,
            displayFloor: displayFloor ?? post.floor,
          ),
        ],
        _fallbackFullKey = captureKey ?? GlobalKey();

  final List<ShareFloorData> floors;
  final String? threadSubject;
  final ThreadPoll? poll;
  final ShareCaptureKeys? captureKeys;
  final GlobalKey _fallbackFullKey;

  /// Logical layout width for the share card.
  static const double cardWidth = 600;

  /// Share-card body size (logical px).
  static const double shareBodySize = 18;

  GlobalKey get _fullKey => captureKeys?.full ?? _fallbackFullKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseTextTheme = Theme.of(context).textTheme;
    final textTheme = shareTextTheme(baseTextTheme);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(textTheme: textTheme),
        child: Builder(
          builder: (context) {
            return RepaintBoundary(
              key: _fullKey,
              child: SizedBox(
                width: cardWidth,
                child: Card(
                  elevation: 0,
                  color: S1Surface.card(scheme),
                  shape: const RoundedRectangleBorder(
                    borderRadius: S1Shape.medium,
                  ),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShareCardHeader(
                        captureKey: captureKeys?.header,
                        threadSubject: threadSubject,
                      ),
                      for (var i = 0; i < floors.length; i++)
                        ShareFloorBlock(
                          captureKey: captureKeys != null &&
                                  i < captureKeys!.floors.length
                              ? captureKeys!.floors[i]
                              : null,
                          floor: floors[i],
                          poll: _pollForFloor(floors[i]),
                          showLeadingDivider: i > 0,
                        ),
                      ShareCardFooter(captureKey: captureKeys?.footer),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ThreadPoll? _pollForFloor(ShareFloorData floor) {
    if (poll == null) return null;
    if (floor.displayFloor != 1) return null;
    return poll;
  }

  /// Scale the whole card type ramp from a larger body so hierarchy holds.
  static TextTheme shareTextTheme(TextTheme base) {
    const scale = shareBodySize / S1Typography.defaultBodySize;
    double scaled(double? size, double fallback) => (size ?? fallback) * scale;

    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        fontSize: scaled(base.titleLarge?.fontSize, 22),
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: scaled(base.titleMedium?.fontSize, 16),
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: scaled(base.titleSmall?.fontSize, 14),
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: scaled(base.bodyLarge?.fontSize, 16),
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: shareBodySize,
        height: S1Typography.defaultBodyLineHeight,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: scaled(base.bodySmall?.fontSize, 12),
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: scaled(base.labelMedium?.fontSize, 12),
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: scaled(base.labelSmall?.fontSize, 11),
      ),
    );
  }
}

/// Brand + optional thread title (once per card).
class ShareCardHeader extends StatelessWidget {
  const ShareCardHeader({
    super.key,
    this.captureKey,
    this.threadSubject,
  });

  final GlobalKey? captureKey;
  final String? threadSubject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          ),
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
        ],
      ),
    );

    if (captureKey == null) return content;
    return RepaintBoundary(
      key: captureKey,
      child: ColoredBox(
        color: S1Surface.card(scheme),
        child: SizedBox(width: ShareCard.cardWidth, child: content),
      ),
    );
  }
}

/// Author row + BBCode body (+ optional poll for floor #1).
class ShareFloorBlock extends StatelessWidget {
  const ShareFloorBlock({
    super.key,
    required this.floor,
    this.poll,
    this.captureKey,
    this.showLeadingDivider = false,
  });

  final ShareFloorData floor;
  final ThreadPoll? poll;
  final GlobalKey? captureKey;
  final bool showLeadingDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final post = floor.post;
    final timeStr = formatDateTime(post.dateline);
    final imageIndexCounter = PostImageIndexCounter();

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLeadingDivider) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            const SizedBox(height: 16),
          ],
          _ShareAuthorRow(
            post: post,
            floor: floor.displayFloor,
            timeStr: timeStr,
          ),
          const SizedBox(height: 16),
          ForceShowImages(
            enabled: true,
            child: BbcodeRenderer(
              bbcode: post.message,
              imageIndexCounter: imageIndexCounter,
              imagesExpanded: true,
            ),
          ),
          if (poll != null) _SharePollView(poll: poll!),
        ],
      ),
    );

    if (captureKey == null) return content;
    return RepaintBoundary(
      key: captureKey,
      child: ColoredBox(
        color: S1Surface.card(scheme),
        child: SizedBox(width: ShareCard.cardWidth, child: content),
      ),
    );
  }
}

/// Client attribution footer.
class ShareCardFooter extends StatelessWidget {
  const ShareCardFooter({super.key, this.captureKey});

  final GlobalKey? captureKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
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
    );

    if (captureKey == null) return content;
    return RepaintBoundary(
      key: captureKey,
      child: ColoredBox(
        color: S1Surface.card(scheme),
        child: SizedBox(width: ShareCard.cardWidth, child: content),
      ),
    );
  }
}

class _ShareAuthorRow extends StatelessWidget {
  const _ShareAuthorRow({
    required this.post,
    required this.floor,
    required this.timeStr,
  });

  final Post post;
  final int floor;
  final String timeStr;

  @override
  Widget build(BuildContext context) {
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

class _SharePollView extends StatelessWidget {
  const _SharePollView({required this.poll});

  final ThreadPoll poll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: S1Alpha.light),
        borderRadius: S1Shape.medium,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                '投票',
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                poll.voteModeLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...poll.options.map((option) => _buildOption(context, option)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '共 ${formatCount(poll.votersCount)} 人参与 · ${poll.remainTimeLabel}',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, PollOption option) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showResults = poll.showResults;
    final barColor = pollBarColor(option.colorHex, scheme);
    final highlight = option.isUserVote;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight
              ? scheme.primaryContainer.withValues(alpha: S1Alpha.light)
              : Colors.transparent,
          borderRadius: S1Shape.small,
          border: highlight
              ? Border.all(color: scheme.primary, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlight)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 2),
                    child: Icon(
                      Icons.how_to_vote,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    option.text,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: highlight ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (highlight)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Badge(
                      label: Text(
                        '我的投票',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: scheme.primaryContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                    ),
                  ),
                if (showResults) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${option.percent.toStringAsFixed(option.percent == option.percent.roundToDouble() ? 0 : 1)}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (showResults) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: S1Shape.extraSmall,
                child: LinearProgressIndicator(
                  value: (option.percent / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${formatCount(option.votes)} 票',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
