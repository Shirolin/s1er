import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/poll.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/s1_snack_bar.dart';

Color _pollBarColor(String hex, ColorScheme scheme) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return scheme.primary;
}

class PollCard extends ConsumerStatefulWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.tid,
  });

  final ThreadPoll poll;
  final String tid;

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  final Set<String> _selectedIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _syncUserVotes(widget.poll);
  }

  @override
  void didUpdateWidget(covariant PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.userVotedOptionIds != widget.poll.userVotedOptionIds) {
      _syncUserVotes(widget.poll);
    }
  }

  void _syncUserVotes(ThreadPoll poll) {
    _selectedIds
      ..clear()
      ..addAll(poll.userVotedOptionIds);
  }

  void _toggleOption(PollOption option) {
    setState(() {
      if (widget.poll.multiple) {
        if (_selectedIds.contains(option.id)) {
          _selectedIds.remove(option.id);
        } else if (_selectedIds.length < widget.poll.maxChoices) {
          _selectedIds.add(option.id);
        }
      } else {
        _selectedIds
          ..clear()
          ..add(option.id);
      }
    });
  }

  Future<void> _submitVote() async {
    if (_selectedIds.isEmpty) {
      S1SnackBar.show(context, message: '请至少选择一个选项');
      return;
    }

    setState(() => _submitting = true);
    try {
      final error = await ref.read(apiServiceProvider).votePoll(
            tid: widget.tid,
            optionIds: _selectedIds.toList(),
          );
      if (!mounted) return;

      if (error != null) {
        S1SnackBar.show(context, message: error);
        return;
      }

      S1SnackBar.show(context, message: '投票成功');

      final uid = ref.read(authStateProvider).user?.uid;
      if (uid != null && uid.isNotEmpty) {
        await ref
            .read(pollVoteCacheProvider(uid))
            .saveVotes(widget.tid, _selectedIds.toList());
      }

      await ref.read(postProvider(widget.tid).notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      S1SnackBar.show(context, message: '投票失败: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;
    final showResults = poll.showResults;
    final canInteract = poll.canVote && isLoggedIn;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
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
            ...poll.options.map(
              (option) => _PollOptionTile(
                option: option,
                selected: _selectedIds.contains(option.id),
                isUserVote: option.isUserVote,
                showResults: showResults,
                canSelect: canInteract,
                multiple: poll.multiple,
                barColor: _pollBarColor(option.colorHex, scheme),
                onTap: canInteract ? () => _toggleOption(option) : null,
              ),
            ),
            if (poll.hasUserVoted) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '已标注您投过的选项',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
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
            if (poll.canVote && !isLoggedIn) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                '登录后可参与投票',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => context.push('/login'),
                  child: const Text('去登录'),
                ),
              ),
            ] else if (canInteract) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submitVote,
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Text('提交投票'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.selected,
    required this.isUserVote,
    required this.showResults,
    required this.canSelect,
    required this.multiple,
    required this.barColor,
    this.onTap,
  });

  final PollOption option;
  final bool selected;
  final bool isUserVote;
  final bool showResults;
  final bool canSelect;
  final bool multiple;
  final Color barColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final highlight = isUserVote || (selected && canSelect);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlight
            ? scheme.primaryContainer.withValues(alpha: S1Alpha.light)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: S1Shape.small,
          side: isUserVote
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: S1Shape.small,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canSelect) ...[
                      if (multiple)
                        Checkbox(
                          value: selected,
                          onChanged: onTap == null ? null : (_) => onTap!(),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 4, top: 2),
                          child: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                    ] else if (isUserVote) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: Icon(
                          Icons.how_to_vote,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        option.text,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: highlight ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    if (isUserVote)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Chip(
                          label: Text(
                            '我的投票',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: scheme.primaryContainer,
                          side: BorderSide.none,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
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
        ),
      ),
    );
  }
}