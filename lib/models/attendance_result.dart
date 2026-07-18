enum AttendanceOutcome { signedNow, alreadySigned, failed, unknown }

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
