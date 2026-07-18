import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_result.dart';
import '../services/forum_tools_service.dart';
import '../services/settings_store.dart';
import '../utils/daily_attendance_store.dart';
import 'auth_provider.dart';
import 'forum_tools_provider.dart';
import 'settings_provider.dart';

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
  DailyAttendanceState build() {
    final auth = ref.watch(authStateProvider);
    final uid = auth.user?.uid.trim() ?? '';
    if (!auth.isLoggedIn || uid.isEmpty) {
      return const DailyAttendanceState();
    }

    final store = _trySettingsStore();
    if (store != null &&
        DailyAttendanceStore.matches(
          raw: store.get(DailyAttendanceStore.settingsKey),
          uid: uid,
          now: DateTime.now(),
        )) {
      return const DailyAttendanceState(
        result: AttendanceResult(
          outcome: AttendanceOutcome.alreadySigned,
          message: '今日已签到',
        ),
      );
    }
    return const DailyAttendanceState();
  }

  ForumToolsService get _service => ref.read(forumToolsServiceProvider);

  SettingsStore? _trySettingsStore() {
    try {
      return ref.read(settingsStoreProvider);
    } on Object {
      return null;
    }
  }

  /// 用户显式触发；并发点击在提交期间直接忽略。
  Future<void> sign() async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true);
    try {
      final result = await _service.dailySign();
      if (!ref.mounted) return;
      if (result.isSignedToday) {
        _persistSignedToday();
      }
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

  void _persistSignedToday() {
    final uid = ref.read(authStateProvider).user?.uid.trim() ?? '';
    if (uid.isEmpty) return;
    final store = _trySettingsStore();
    store?.put(
      DailyAttendanceStore.settingsKey,
      DailyAttendanceStore.payload(uid: uid, now: DateTime.now()),
    );
  }
}

final dailyAttendanceProvider =
    NotifierProvider.autoDispose<DailyAttendanceNotifier, DailyAttendanceState>(
  DailyAttendanceNotifier.new,
);
