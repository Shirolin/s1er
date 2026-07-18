import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/search_result.dart';
import '../models/thread_destination.dart';
import '../models/user.dart';
import '../providers/search_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/thread_navigation.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/user_profile_sheet.dart';
import '../widgets/web_avatar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref.read(searchProvider.notifier).submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(searchProvider);
    final hasQuery = _controller.text.trim().isNotEmpty;
    final canSubmit = hasQuery && !state.isLoading && !state.isCoolingDown;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<SearchType>(
            segments: const [
              ButtonSegment(
                value: SearchType.forum,
                label: Text('主题'),
                icon: Icon(Icons.article_outlined),
              ),
              ButtonSegment(
                value: SearchType.user,
                label: Text('用户'),
                icon: Icon(Icons.person_outline),
              ),
            ],
            selected: {state.type},
            onSelectionChanged: state.isLoading
                ? null
                : (value) {
                    ref.read(searchProvider.notifier).setType(value.first);
                    _controller.clear();
                  },
            style: S1SegmentedButtonStyle.forScheme(scheme),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            controller: _controller,
            focusNode: _focusNode,
            hintText: state.type == SearchType.forum ? '搜索主题…' : '搜索用户…',
            leading: const Icon(Icons.search),
            trailing: [
              if (hasQuery)
                IconButton(
                  tooltip: '清除',
                  onPressed: state.isLoading
                      ? null
                      : () {
                          _controller.clear();
                        },
                  icon: const Icon(Icons.clear),
                ),
              IconButton(
                tooltip: state.isCoolingDown
                    ? '搜索间隔中'
                    : hasQuery
                        ? '搜索'
                        : '请输入搜索关键词',
                onPressed: canSubmit ? _submit : null,
                icon: state.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ],
            onSubmitted: canSubmit ? (_) => _submit() : null,
          ),
        ),
        if (state.isCoolingDown && state.hasSearched)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '搜索间隔中，${state.cooldownRemainingSeconds} 秒后可再搜索',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(child: _SearchBody(controller: _controller)),
      ],
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (state.isLoading && !state.hasSearched) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null &&
        state.forumHits.isEmpty &&
        state.userHits.isEmpty) {
      final err = state.error!;
      if (err is Exception) {
        return S1ErrorView(
          error: err,
          onRetry: () =>
              ref.read(searchProvider.notifier).submit(controller.text),
          onLogin: () => context.push('/login'),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                        .read(searchProvider.notifier)
                        .submit(controller.text),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                state.type == SearchType.forum ? '搜索主题与帖子' : '搜索用户',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '输入关键词后按回车或点击箭头',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.type == SearchType.forum) {
      if (state.forumHits.isEmpty) {
        return _EmptyResult(query: state.query);
      }
      return Column(
        children: [
          if (state.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '找到 ${state.count} 条结果',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                  itemCount: state.forumHits.length,
                  itemBuilder: (context, index) {
                    final hit = state.forumHits[index];
                    return _ForumHitTile(hit: hit);
                  },
                ),
                if (state.isLoading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          if (state.totalPages > 1)
            PaginationBar(
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (page) =>
                  ref.read(searchProvider.notifier).goToPage(page),
              sheetSubtitle: state.query,
            ),
        ],
      );
    }

    if (state.userHits.isEmpty) {
      return _EmptyResult(query: state.query);
    }
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: state.userHits.length,
          itemBuilder: (context, index) {
            final hit = state.userHits[index];
            return _UserHitTile(hit: hit);
          },
        ),
        if (state.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '未找到「$query」相关结果',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ForumHitTile extends StatelessWidget {
  const _ForumHitTile({required this.hit});

  final ForumSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasMeta = hit.forumName.isNotEmpty ||
        hit.author.isNotEmpty ||
        hit.dateline.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          ThreadRouteCodec.encodePath(ResumeThread(hit.tid)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
              if (hit.snippet.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  hit.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (hasMeta) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hit.forumName.isNotEmpty)
                      Chip(
                        avatar: Icon(
                          Icons.forum_outlined,
                          color: scheme.onSecondaryContainer,
                        ),
                        label: Text(hit.forumName),
                        backgroundColor: scheme.secondaryContainer,
                        side: BorderSide.none,
                        labelStyle: textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    if (hit.author.isNotEmpty)
                      _SearchMeta(
                        icon: Icons.person_outline,
                        text: hit.author,
                      ),
                    if (hit.dateline.isNotEmpty)
                      _SearchMeta(
                        icon: Icons.schedule,
                        text: hit.dateline,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserHitTile extends ConsumerWidget {
  const _UserHitTile({required this.hit});

  final UserSearchHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = User.resolveAvatarUrl(
      'https://avatar.stage1st.com/avatar.php?uid=${hit.uid}&size=small',
    );

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: WebAvatar(
          url: avatarUrl,
          radius: 20,
          fallbackLetter: hit.name.isNotEmpty ? hit.name[0] : '?',
        ),
        title: Text(hit.name, style: textTheme.titleMedium),
        subtitle: Text(
          'UID ${hit.uid}',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showUserProfileSheet(
            context,
            future: ref.read(userProfileProvider(hit.uid).future),
          );
        },
      ),
    );
  }
}

class _SearchMeta extends StatelessWidget {
  const _SearchMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
