enum AttendanceOutcome {
  /// 页面显示可以签到（尚未签）。
  ready,
  signedNow,
  alreadySigned,
  failed,
  unavailable,
  unknown
}

class AttendanceResult {
  const AttendanceResult({required this.outcome, required this.message});

  final AttendanceOutcome outcome;
  final String message;

  bool get isSuccess =>
      outcome == AttendanceOutcome.signedNow ||
      outcome == AttendanceOutcome.alreadySigned;

  bool get isSignedToday =>
      outcome == AttendanceOutcome.signedNow ||
      outcome == AttendanceOutcome.alreadySigned;
}
