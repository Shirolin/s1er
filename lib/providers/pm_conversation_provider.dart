import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blacklist_record.dart';
import '../models/private_message.dart';
import '../models/pm_send_result.dart';
import '../services/api_service.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart';
import 'blacklist_provider.dart';

class PmConversationState {
  const PmConversationState({
    this.items = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isBlocked = false,
    this.isSending = false,
    this.sendStatusUnknown = false,
    this.sendError,
  });

  final List<PrivateMessage> items;
  final int currentPage;
  final int totalPages;
  final bool isBlocked;
  final bool isSending;
  final bool sendStatusUnknown;
  final String? sendError;

  PmConversationState copyWith({
    List<PrivateMessage>? items,
    int? currentPage,
    int? totalPages,
    bool? isBlocked,
    bool? isSending,
    bool? sendStatusUnknown,
    String? sendError,
    bool clearSendError = false,
  }) {
    return PmConversationState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isBlocked: isBlocked ?? this.isBlocked,
      isSending: isSending ?? this.isSending,
      sendStatusUnknown: sendStatusUnknown ?? this.sendStatusUnknown,
      sendError: clearSendError ? null : (sendError ?? this.sendError),
    );
  }
}

class PmConversationNotifier extends AsyncNotifier<PmConversationState> {
  PmConversationNotifier(this.touid);

  final String touid;

  @override
  Future<PmConversationState> build() {
    final blocked = ref.watch(
      blacklistHasScopeProvider(
        (uid: touid, scope: BlacklistRecord.scopePm),
      ),
    );
    if (blocked) {
      return Future.value(const PmConversationState(isBlocked: true));
    }
    return _loadPage(1);
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  Future<PmConversationState> _loadPage(int page) async {
    final result = await _apiService.getPmConversation(touid, page: page);
    return PmConversationState(
      items: result.items,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
    );
  }

  Future<void> goToPage(int page) async {
    final previous = state.asData?.value;
    state = await AsyncValue.guard(() => _loadPage(page));
    if (state.hasError && previous != null) {
      state = AsyncValue.data(previous);
    }
  }

  Future<void> refresh() async {
    final page = state.asData?.value.currentPage ?? 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(page));
  }

  Future<PmSendResult> sendMessage(String message) async {
    final selfUid = ref.read(authStateProvider).user?.uid;
    if (selfUid != null && selfUid.isNotEmpty && selfUid == touid) {
      return const PmSendResult.rejected('不能给自己发送私信');
    }
    final current = state.asData?.value;
    if (current?.isBlocked == true) {
      return const PmSendResult.rejected('该用户已在私信范围中被屏蔽');
    }
    if (current?.sendStatusUnknown == true) {
      return const PmSendResult.uncertain('请先刷新会话确认上一条私信状态');
    }
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          isSending: true,
          clearSendError: true,
        ),
      );
    }
    final result = await _apiService.sendPrivateMessage(
      touid: touid,
      message: message,
    );
    final latest = state.asData?.value ?? current;
    if (latest != null) {
      state = AsyncValue.data(
        latest.copyWith(
          isSending: false,
          sendStatusUnknown: result.isUncertain,
          sendError: result.message,
        ),
      );
    }
    if (result.isSuccess) {
      try {
        state = AsyncValue.data(await _loadPage(1));
      } catch (_) {
        // 发送已经成功；会话刷新失败不回滚发送结果。
      }
    }
    return result;
  }
}

final pmConversationProvider = AsyncNotifierProvider.autoDispose
    .family<PmConversationNotifier, PmConversationState, String>(
  PmConversationNotifier.new,
);
