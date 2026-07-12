import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/favorite_item.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_membership_provider.dart';
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

  @override
  ConsumerState<FavoriteBookmarkButton> createState() =>
      _FavoriteBookmarkButtonState();
}

class _FavoriteBookmarkButtonState extends ConsumerState<FavoriteBookmarkButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
    if (!isLoggedIn) {
      if (!mounted) return;
      unawaited(context.push('/login'));
      return;
    }

    if (_busy || widget.id.isEmpty) return;

    final membership = ref.read(favoriteMembershipProvider);
    final isFavorited = membership.isFavorited(widget.type, widget.id);
    if (isFavorited) {
      final confirmed = await confirmUnfavorite(context);
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);

    final notifier = ref.read(favoriteMembershipProvider.notifier);
    final error = widget.type == FavoriteType.thread
        ? await notifier.toggleThread(widget.id)
        : await notifier.toggleForum(widget.id);

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      S1SnackBar.show(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(favoriteMembershipProvider);
    final isFavorited = membership.isFavorited(widget.type, widget.id);

    if (_busy || membership.isLoading) {
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
      tooltip: isFavorited ? '取消收藏' : '收藏',
      icon: Icon(isFavorited ? Icons.bookmark : Icons.bookmark_outline),
      onPressed: _toggle,
    );
  }
}
