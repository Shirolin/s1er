import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../models/private_message_item.dart';
import '../providers/pm_conversation_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/window_size.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pm_message_bubble.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_list_boundary_footer.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../utils/pm_draft_store.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_desktop_scaffold.dart';
import '../widgets/web_avatar.dart';

class PmConversationScreen extends ConsumerStatefulWidget {
  const PmConversationScreen({
    super.key,
    required this.touid,
    this.partnerName,
  });

  final String touid;
  final String? partnerName;

  @override
  ConsumerState<PmConversationScreen> createState() =>
      _PmConversationScreenState();
}

class _PmComposer extends StatelessWidget {
  const _PmComposer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onSend,
    required this.isDesktop,
    required this.partnerName,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final PmConversationState state;
  final VoidCallback onSend;
  final bool isDesktop;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canSend = controller.text.trim().isNotEmpty &&
        !state.isSending &&
        !state.sendStatusUnknown;
    final composerContent = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.sendStatusUnknown || state.sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                state.sendError ?? '请先刷新会话确认上一条私信状态',
                style: textTheme.bodySmall?.copyWith(
                  color: state.sendStatusUnknown
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !state.isSending && !state.sendStatusUnknown,
                  textInputAction: TextInputAction.newline,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: isDesktop ? '回复 $partnerName' : '私信内容',
                    hintText: '输入私信…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: S1BottomBarStyle.minTouchTarget,
                child: isDesktop
                    ? FilledButton.icon(
                        onPressed: canSend ? onSend : null,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(state.isSending ? '发送中…' : '发送'),
                      )
                    : IconButton.filled(
                        onPressed: canSend ? onSend : null,
                        tooltip: state.isSending ? '发送中' : '发送私信',
                        icon: Icon(
                          state.isSending
                              ? Icons.hourglass_top
                              : Icons.send_outlined,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Material(
        color: isDesktop ? scheme.surface : scheme.surfaceContainer,
        child: isDesktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: S1Breakpoints.contentWidthLarge,
                  ),
                  child: Card(
                    key: const ValueKey('pm_desktop_composer'),
                    elevation: 0,
                    color: S1Surface.card(scheme),
                    margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: S1Shape.large,
                    ),
                    child: composerContent,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: composerContent,
              ),
      ),
    );
  }
}

class _PmConversationScreenState extends ConsumerState<PmConversationScreen> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_scheduleDraftSave);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _persistDraft();
    _messageController.removeListener(_scheduleDraftSave);
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _restoreDraft() {
    if (!mounted) return;
    try {
      final store = ref.read(settingsStoreProvider);
      final message = PmDraftStore.parse(
        store.get<Object>(PmDraftStore.settingsKey),
      )[widget.touid];
      if (!mounted || message == null || message.isEmpty) return;
      _messageController.value = TextEditingValue(
        text: message,
        selection: TextSelection.collapsed(offset: message.length),
      );
      S1SnackBar.show(context, message: '已恢复私信草稿', bottomClearance: 72);
    } on Object {
      // 部分测试未注入 SettingsStore 时跳过草稿恢复。
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _persistDraft);
    if (mounted) setState(() {});
  }

  void _persistDraft() {
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = PmDraftStore.parse(
        store.get<Object>(PmDraftStore.settingsKey),
      );
      store.put(
        PmDraftStore.settingsKey,
        PmDraftStore.toStoreValue(
          PmDraftStore.upsert(drafts, widget.touid, _messageController.text),
        ),
      );
    } on Object {
      // 部分测试未注入 SettingsStore 时跳过草稿持久化。
    }
  }

  void _clearDraft() {
    _draftTimer?.cancel();
    try {
      final store = ref.read(settingsStoreProvider);
      final drafts = PmDraftStore.parse(
        store.get<Object>(PmDraftStore.settingsKey),
      );
      drafts.remove(widget.touid);
      store.put(PmDraftStore.settingsKey, PmDraftStore.toStoreValue(drafts));
    } on Object {
      // 部分测试未注入 SettingsStore 时跳过草稿清理。
    }
  }

  Future<void> _sendMessage(PmConversationState state) async {
    final message = _messageController.text.trim();
    if (message.isEmpty || state.isSending) return;
    if (state.sendStatusUnknown) {
      S1SnackBar.show(context, message: '请先刷新会话确认上一条私信状态');
      return;
    }
    final name = widget.partnerName?.trim().isNotEmpty == true
        ? widget.partnerName!.trim()
        : 'UID ${widget.touid}';
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '确认发送私信？',
      content:
          '收件人：$name\n内容：${message.length > 100 ? '${message.substring(0, 100)}…' : message}',
      confirmLabel: '发送',
    );
    if (!mounted || !confirmed) return;
    final result = await ref
        .read(pmConversationProvider(widget.touid).notifier)
        .sendMessage(message);
    if (!mounted) return;
    if (result.isSuccess) {
      _messageController.clear();
      _clearDraft();
      S1SnackBar.show(context, message: '私信已发送');
    } else {
      S1SnackBar.show(
        context,
        message: result.message ?? '私信发送失败',
        bottomClearance: 72,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = pmConversationProvider(widget.touid);
    final async = ref.watch(provider);
    final title = widget.partnerName?.trim();
    final displayName = title != null && title.isNotEmpty ? title : '私信会话';
    final isDesktop = context.isExpandedOrAbove;

    return S1DesktopScaffold(
      highlightedTab: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WebAvatar(
                url: PrivateMessageItem.avatarUrlForUid(widget.touid),
                radius: isDesktop ? 18 : 16,
                fallbackLetter: displayName.characters.first,
              ),
              const SizedBox(width: 10),
              if (isDesktop)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName),
                    Text(
                      'UID ${widget.touid}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                )
              else
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          actions: [
            AppBarMoreMenu(
              onRefresh: () => ref.read(provider.notifier).refresh(),
              browserUrl: ApiConfig.pmConversationBrowserUrl(
                touid: widget.touid,
                page: async.asData?.value.currentPage ?? 1,
              ),
            ),
          ],
        ),
        body: async.when(
          loading: () => const Column(
            children: [
              LinearProgressIndicator(),
              Expanded(child: SizedBox()),
            ],
          ),
          error: (error, stack) => S1ErrorView(
            error: error,
            onRetry: () => S1Haptics.wrapRefresh(
              () => ref.read(provider.notifier).refresh(),
            ),
            onLogin: () => context.push('/login'),
          ),
          data: (state) {
            if (state.isBlocked) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('该用户已在私信范围中被屏蔽'),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: S1SwipePagination(
                    key: _swipeKey,
                    currentPage: state.currentPage,
                    totalPages: state.totalPages,
                    onPageChanged: (page) =>
                        ref.read(provider.notifier).goToPage(page),
                    pageBuilder: (context, scrollController) => Center(
                      child: ConstrainedBox(
                        key: const ValueKey('pm_conversation_canvas'),
                        constraints: BoxConstraints(
                          maxWidth: isDesktop
                              ? S1Breakpoints.contentWidthLarge
                              : double.infinity,
                        ),
                        child: RefreshIndicator(
                          onRefresh: () => S1Haptics.wrapRefresh(
                            () => ref.read(provider.notifier).refresh(),
                          ),
                          child: state.items.isEmpty
                              ? ListView(
                                  controller: scrollController,
                                  children: const [
                                    SizedBox(height: 48),
                                    Center(child: Text('暂无会话内容')),
                                  ],
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isDesktop ? 16 : 8,
                                  ),
                                  itemCount: state.items.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index >= state.items.length) {
                                      return S1ListBoundaryFooter(
                                        kind: pagedBoundaryKind(
                                          currentPage: state.currentPage,
                                          totalPages: state.totalPages,
                                        ),
                                      );
                                    }
                                    return PmMessageBubble(
                                      key: ValueKey(
                                        'pm_message_${state.items[index].id}_$index',
                                      ),
                                      message: state.items[index],
                                      compact: !isDesktop,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop
                          ? S1Breakpoints.contentWidthLarge
                          : double.infinity,
                    ),
                    child: PaginationBar(
                      currentPage: state.currentPage,
                      totalPages: state.totalPages,
                      onPageChanged: (page) =>
                          ref.read(provider.notifier).goToPage(page),
                    ),
                  ),
                ),
                if (!state.isBlocked)
                  _PmComposer(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    state: state,
                    onSend: () => _sendMessage(state),
                    isDesktop: isDesktop,
                    partnerName: displayName,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
