import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_result.dart';
import '../services/forum_tools_service.dart';
import 'auth_provider.dart';
import 'forum_tools_provider.dart';

class DailyAttendanceState {
  const DailyAttendanceState({
    this.isSubmitting = false,
    this.result,
    this.loadingStatus = false,
  });

  final bool isSubmitting;
  final AttendanceResult? result;

  /// 首次进个人页时正在读取插件页面状态。
  final bool loadingStatus;

  DailyAttendanceState copyWith({
    bool? isSubmitting,
    AttendanceResult? result,
    bool? loadingStatus,
  }) {
    return DailyAttendanceState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      loadingStatus: loadingStatus ?? this.loadingStatus,
    );
  }
}

class DailyAttendanceNotifier extends Notifier<DailyAttendanceState> {
  @override
  DailyAttendanceState build() {
    final auth = ref.watch(authStateProvider);
    final uid = auth.user?.uid.trim() ?? '';
    if (!auth.isLoggedIn || uid.isEmpty) {
      return const DailyAttendanceState();
    }

    // 页面是唯一真源（插件没有只读接口），进入时主动读一次。
    Future.microtask(loadStatus);

    return const DailyAttendanceState(loadingStatus: true);
  }

  ForumToolsService get _service => ref.read(forumToolsServiceProvider);

  /// 读取插件页面状态；只读，不产生签到写入。
  Future<void> loadStatus() async {
    try {
      final result = await _service.fetchAttendanceStatus();
      if (!ref.mounted) return;
      if (result.outcome == AttendanceOutcome.unavailable) {
        state = DailyAttendanceState(result: result);
        return;
      }
      state = DailyAttendanceState(result: result);
    } catch (e) {
      if (!ref.mounted) return;
      state = DailyAttendanceState(
        result: AttendanceResult(
          outcome: AttendanceOutcome.unknown,
          message: e.toString(),
        ),
      );
    }
  }

  /// 用户显式触发；并发点击在提交期间直接忽略。
  Future<void> sign() async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true);
    try {
      final result = await _service.dailySign();
      if (!ref.mounted) return;
      state = DailyAttendanceState(isSubmitting: false, result: result);
    } catch (e) {
      if (!ref.mounted) return;
      state = DailyAttendanceState(
        isSubmitting: false,
        result: AttendanceResult(
          outcome: AttendanceOutcome.failed,
          message: e.toString(),
        ),
      );
    }
  }
}

final dailyAttendanceProvider =
    NotifierProvider.autoDispose<DailyAttendanceNotifier, DailyAttendanceState>(
  DailyAttendanceNotifier.new,
);
