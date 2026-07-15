enum EditPostDisposition { success, rejected, conflict, uncertain }

class EditPostSubmitResult {
  const EditPostSubmitResult._({
    required this.disposition,
    this.message,
  });

  const EditPostSubmitResult.success({String? message})
      : this._(disposition: EditPostDisposition.success, message: message);

  const EditPostSubmitResult.rejected(String message)
      : this._(disposition: EditPostDisposition.rejected, message: message);

  const EditPostSubmitResult.conflict(String message)
      : this._(disposition: EditPostDisposition.conflict, message: message);

  const EditPostSubmitResult.uncertain(String message)
      : this._(disposition: EditPostDisposition.uncertain, message: message);

  final EditPostDisposition disposition;
  final String? message;

  bool get isSuccess => disposition == EditPostDisposition.success;
  bool get isUncertain => disposition == EditPostDisposition.uncertain;
  bool get isConflict => disposition == EditPostDisposition.conflict;
}
