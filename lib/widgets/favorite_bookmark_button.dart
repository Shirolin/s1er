import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/favorite_item.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_membership_provider.dart';
import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';
import 'favorite_confirm_dialog.dart';

class FavoriteBookmarkButton extends ConsumerStatefulWidget {
  const FavoriteBookmarkButton({
    super.key,
    required this.type,
    required this.id,
  });

  final FavoriteType type;
  final String id;

  IconData _icon(bool isFavorited) {
    return switch (type) {
      FavoriteType.forum => isFavorited
          ? Icons.collections_bookmark
          : Icons.collections_bookmark_outlined,
      FavoriteType.thread =>
        isFavorited ? Icons.bookmark : Icons.bookmark_outline,
    };
  }

  String _tooltip(bool isFavorited) {
    return switch (type) {
      FavoriteType.forum => isFavorited ? '取消收藏版块' : '收藏版块',
      FavoriteType.thread => isFavorited ? '取消收藏主题' : '收藏主题',
    };
  }

  @override
  ConsumerState<FavoriteBookmarkButton> createState() =>
      _FavoriteBookmarkButtonState();
}

class _FavoriteBookmarkButtonState
    extends ConsumerState<FavoriteBookmarkButton> {
  bool _busy = false;
  bool _syncRequested = false;

  Future<void> _toggle() async {
    final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
    if (!isLoggedIn) {
      if (!mounted) return;
      unawaited(context.push('/login'));
      return;
    }

    if (_busy || widget.id.isEmpty) return;

    await ref.read(favoriteMembershipProvider.notifier).ensureSynced();
    if (!mounted) return;

    final membership = ref.read(favoriteMembershipProvider);
    final isFavorited = membership.isFavorited(widget.type, widget.id);
    if (isFavorited) {
      final confirmed = await confirmUnfavorite(context);
      if (!confirmed || !mounted) return;
    }

    S1Haptics.medium();
    setState(() => _busy = true);

    final notifier = ref.read(favoriteMembershipProvider.notifier);
    final error = widget.type == FavoriteType.thread
        ? await notifier.toggleThread(widget.id)
        : await notifier.toggleForum(widget.id);

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      S1SnackBar.error(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_syncRequested && ref.read(authStateProvider).isLoggedIn) {
      _syncRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(favoriteMembershipProvider.notifier).ensureSynced();
      });
    }

    final isFavorited = ref.watch(
      favoriteMembershipProvider.select(
        (m) => m.isFavorited(widget.type, widget.id),
      ),
    );
    final isLoading = ref.watch(
      favoriteMembershipProvider.select((m) => m.isLoading),
    );

    if (_busy || isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: widget._tooltip(isFavorited),
      icon: Icon(widget._icon(isFavorited)),
      onPressed: _toggle,
    );
  }
}
