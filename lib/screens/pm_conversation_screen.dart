import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../providers/pm_conversation_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pm_message_bubble.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../utils/pm_draft_store.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/s1_confirm_dialog.dart';

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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final PmConversationState state;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canSend = controller.text.trim().isNotEmpty &&
        !state.isSending &&
        !state.sendStatusUnknown;
    return SafeArea(
      top: false,
      child: Material(
        color: scheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                      decoration: const InputDecoration(
                        labelText: '私信内容',
                        hintText: '输入私信…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSend ? onSend : null,
                    child: Text(state.isSending ? '发送中…' : '发送'),
                  ),
                ],
              ),
            ],
          ),
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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(title != null && title.isNotEmpty ? title : '私信会话'),
        actions: [
          AppBarMoreMenu(
            onRefresh: () => ref.read(provider.notifier).refresh(),
            browserUrl: '${ApiConfig.baseUrl}/home.php'
                '?mod=space&do=pm&subop=view&touid=${widget.touid}',
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
          onRetry: () => ref.read(provider.notifier).refresh(),
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
                  pageBuilder: (context, scrollController) => RefreshIndicator(
                    onRefresh: () => ref.read(provider.notifier).refresh(),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: state.items.length,
                            itemBuilder: (context, index) => PmMessageBubble(
                              key: ValueKey(
                                'pm_message_${state.items[index].id}_$index',
                              ),
                              message: state.items[index],
                            ),
                          ),
                  ),
                ),
              ),
              PaginationBar(
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onPageChanged: (page) =>
                    ref.read(provider.notifier).goToPage(page),
              ),
              if (!state.isBlocked)
                _PmComposer(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  state: state,
                  onSend: () => _sendMessage(state),
                ),
            ],
          );
        },
      ),
    );
  }
}
