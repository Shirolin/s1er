import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_result.dart';
import '../services/forum_tools_service.dart';
import 'forum_tools_provider.dart';

class DailyAttendanceState {
  const DailyAttendanceState({this.isSubmitting = false, this.result});

  final bool isSubmitting;
  final AttendanceResult? result;

  DailyAttendanceState copyWith({
    bool? isSubmitting,
    AttendanceResult? result,
  }) {
    return DailyAttendanceState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
    );
  }
}

class DailyAttendanceNotifier extends Notifier<DailyAttendanceState> {
  @override
  DailyAttendanceState build() => const DailyAttendanceState();

  ForumToolsService get _service => ref.read(forumToolsServiceProvider);

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
