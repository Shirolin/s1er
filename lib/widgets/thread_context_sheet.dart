import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/constants.dart';
import '../models/favorite_item.dart';
import '../models/thread.dart';
import '../models/thread_destination.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_membership_provider.dart';
import '../providers/pinned_threads_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/format_utils.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/thread_navigation.dart';
import 'favorite_confirm_dialog.dart';
import 'page_picker_sheet.dart';
import 's1_adaptive_sheet.dart';
import 'thread_card.dart';

/// 版块列表长按帖子时弹出的操作菜单。
Future<void> showThreadContextSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Thread thread,
  ThreadOpenCallback? onOpenThread,
}) async {
  if (ref.read(authStateProvider).isLoggedIn) {
    await ref.read(favoriteMembershipProvider.notifier).ensureSynced();
  }
  if (!context.mounted) return;

  return showS1AdaptiveSheet<void>(
    context: context,
    builder: (sheetContext) => _ThreadContextSheet(
      thread: thread,
      onOpenThread: onOpenThread,
      parentContext: context,
    ),
  );
}

class _ThreadContextSheet extends ConsumerWidget {
  const _ThreadContextSheet({
    required this.thread,
    required this.onOpenThread,
    required this.parentContext,
  });

  final Thread thread;
  final ThreadOpenCallback? onOpenThread;
  final BuildContext parentContext;

  int _totalPages(Thread thread) => calcThreadTotalPages(thread.replies);

  Future<void> _closeSheetThen(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    Navigator.of(context).pop();
    // 等菜单 route 收起，避免同一次点击穿透到底层 ThreadCard。
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!parentContext.mounted) return;
    await action();
  }

  void _openThreadPage(int page) {
    if (onOpenThread != null) {
      onOpenThread!(ThreadPage(thread.tid, page));
      return;
    }
    if (!parentContext.mounted) return;
    parentContext.push(
      ThreadRouteCodec.encodePath(ThreadPage(thread.tid, page)),
    );
  }

  Future<void> _showPagePicker(BuildContext context) async {
    await _closeSheetThen(context, () async {
      final totalPages = _totalPages(thread);
      const perPage = S1Constants.postsPerPageFallback;
      await showPagePickerSheet(
        context: parentContext,
        totalPages: totalPages,
        subtitle: thread.subject,
        pageItemLabelBuilder: (page) {
          final start = (page - 1) * perPage + 1;
          final end = page * perPage;
          return '第 $start - $end 楼';
        },
        onPageSelected: _openThreadPage,
      );
    });
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    await _closeSheetThen(context, () async {
      final notifier = ref.read(pinnedThreadsProvider.notifier);
      final isPinned = notifier.isPinned(thread.tid);
      if (isPinned) {
        notifier.unpin(thread.tid);
        S1SnackBar.show(parentContext, message: '已取消置顶');
        return;
      }

      final title = thread.subject.trim().isNotEmpty
          ? thread.subject.trim()
          : '帖子 ${thread.tid}';
      final ok = notifier.pin(tid: thread.tid, title: title);
      if (!parentContext.mounted) return;
      if (ok) {
        S1SnackBar.show(parentContext, message: '已钉在首页');
      } else {
        S1SnackBar.show(
          parentContext,
          message: '首页置顶已满（10 条），请先移除一条',
        );
      }
    });
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
    if (!isLoggedIn) {
      await _closeSheetThen(context, () async {
        if (parentContext.mounted) {
          unawaited(parentContext.push('/login'));
        }
      });
      return;
    }

    await ref.read(favoriteMembershipProvider.notifier).ensureSynced();
    if (!context.mounted) return;

    final membership = ref.read(favoriteMembershipProvider);
    final wasFavorited =
        membership.isFavorited(FavoriteType.thread, thread.tid);

    await _closeSheetThen(context, () async {
      if (wasFavorited) {
        final confirmed = await confirmUnfavorite(parentContext);
        if (!confirmed || !parentContext.mounted) return;
      }

      final error = await ref
          .read(favoriteMembershipProvider.notifier)
          .toggleThread(thread.tid);
      if (!parentContext.mounted) return;

      if (error != null) {
        S1SnackBar.error(parentContext, message: error);
        return;
      }
      S1SnackBar.show(
        parentContext,
        message: wasFavorited ? '已取消收藏' : '已收藏',
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final isPinned = ref.watch(
      pinnedThreadsProvider.select(
        (pins) => pins.any((item) => item.tid == thread.tid),
      ),
    );
    final isFavorited = isLoggedIn &&
        ref.watch(
          favoriteMembershipProvider.select(
            (m) => m.isFavorited(FavoriteType.thread, thread.tid),
          ),
        );
    final totalPages = _totalPages(thread);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              thread.subject,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${thread.author} · ${formatFullCount(thread.replies)} 回复'
              '${totalPages > 1 ? ' · 共 $totalPages 页' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 4),
            _ThreadContextActionTile(
              icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isPinned ? '取消置顶' : '钉在首页',
              onTap: () => _togglePin(context, ref),
            ),
            const SizedBox(height: 2),
            _ThreadContextActionTile(
              icon: isFavorited
                  ? Icons.bookmark_remove_outlined
                  : Icons.bookmark_add_outlined,
              label: isFavorited ? '取消收藏' : '收藏帖子',
              destructive: isFavorited,
              onTap: () => _toggleFavorite(context, ref),
            ),
            const SizedBox(height: 2),
            _ThreadContextActionTile(
              icon: Icons.library_books_outlined,
              label: '跳转到某页',
              subtitle: totalPages > 1 ? '共 $totalPages 页' : null,
              onTap: () => _showPagePicker(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadContextActionTile extends StatelessWidget {
  const _ThreadContextActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final iconBackground =
        destructive ? scheme.errorContainer : scheme.secondaryContainer;
    final iconColor =
        destructive ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          S1Haptics.selection();
          onTap();
        },
        borderRadius: S1Shape.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: S1Shape.small,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
