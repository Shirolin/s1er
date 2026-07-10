import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import 'web_avatar.dart';

/// 展示用户资料 BottomSheet（帖子内点击头像触发）。
Future<void> showUserProfileSheet(
  BuildContext context, {
  required Future<User?> future,
  VoidCallback? onFilterByAuthor,
  bool isSelf = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _UserProfileSheet(
      future: future,
      onFilterByAuthor: onFilterByAuthor,
      isSelf: isSelf,
    ),
  );
}

class _UserProfileSheet extends StatelessWidget {
  const _UserProfileSheet({
    required this.future,
    this.onFilterByAuthor,
    this.isSelf = false,
  });

  final Future<User?> future;
  final VoidCallback? onFilterByAuthor;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SafeArea(
            child: SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          );
        }

        return _UserProfileContent(
          user: user,
          onFilterByAuthor: onFilterByAuthor,
          isSelf: isSelf,
        );
      },
    );
  }
}

class _UserProfileContent extends StatelessWidget {
  const _UserProfileContent({
    required this.user,
    this.onFilterByAuthor,
    this.isSelf = false,
  });

  final User user;
  final VoidCallback? onFilterByAuthor;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = User.resolveAvatarUrl(
      user.avatar ??
          'https://avatar.stage1st.com/avatar.php?uid=${user.uid}&size=small',
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              username: user.username,
              groupTitle: user.groupTitle,
              avatarUrl: avatarUrl,
              fallbackLetter:
                  user.username.isNotEmpty ? user.username[0] : '?',
            ),
            const SizedBox(height: 16),
            _StatsRow(
              credits: user.credits,
              posts: user.posts,
              combat: user.combat,
              deadfish: user.deadfish,
            ),
            const SizedBox(height: 12),
            _DetailCard(user: user),
            const SizedBox(height: 16),
            if (isSelf) ...[
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/profile');
                },
                child: const Text('我的资料'),
              ),
            ] else ...[
              Row(
                children: [
                  if (onFilterByAuthor != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onFilterByAuthor!();
                        },
                        child: const Text('只看该作者'),
                      ),
                    ),
                  if (onFilterByAuthor != null) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/user-space/${user.uid}?username=${Uri.encodeComponent(user.username)}',
                        );
                      },
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: const Text('Ta的帖子'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.username,
    required this.groupTitle,
    required this.avatarUrl,
    required this.fallbackLetter,
  });

  final String username;
  final String? groupTitle;
  final String? avatarUrl;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasGroup = groupTitle != null && groupTitle!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        WebAvatar(
          url: avatarUrl,
          radius: 28,
          fallbackLetter: fallbackLetter,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                username,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasGroup) ...[
                const SizedBox(height: 6),
                Chip(
                  label: CompactLabel.text(
                    groupTitle!,
                    style: CompactLabel.style(
                      context,
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: scheme.secondaryContainer,
                  side: BorderSide.none,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.credits,
    required this.posts,
    required this.combat,
    required this.deadfish,
  });

  final int credits;
  final int posts;
  final int combat;
  final int deadfish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(child: _StatCell(label: '积分', value: credits)),
            _VerticalDivider(),
            Expanded(child: _StatCell(label: '帖子', value: posts)),
            _VerticalDivider(),
            Expanded(child: _StatCell(label: '战斗力', value: combat)),
            _VerticalDivider(),
            Expanded(child: _StatCell(label: '死鱼', value: deadfish)),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactLabel.text(
          formatCount(value),
          style: CompactLabel.style(
            context,
            base: textTheme.titleMedium,
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        CompactLabel.text(
          label,
          style: CompactLabel.style(
            context,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      _DetailRow(label: 'UID', value: user.uid),
      if (user.regdate.isNotEmpty)
        _DetailRow(label: '注册时间', value: formatRegDate(user.regdate)),
      if (user.oltime > 0)
        _DetailRow(label: '在线时长', value: '${user.oltime} 小时'),
      if (user.following > 0 || user.follower > 0)
        _DetailRow(
          label: '关注 / 粉丝',
          value: '${user.following} / ${user.follower}',
        ),
    ];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      shape: S1Shape.cardShape,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
