enum PmSendDisposition { success, rejected, uncertain }

class PmSendFormInfo {
  const PmSendFormInfo({this.formhash, this.error});

  final String? formhash;
  final String? error;

  bool get canSend =>
      error == null && formhash != null && formhash!.trim().isNotEmpty;
}

class PmSendResult {
  const PmSendResult({
    required this.disposition,
    this.pmid,
    this.message,
  });

  const PmSendResult.success({String? pmid, String? message})
      : this(
          disposition: PmSendDisposition.success,
          pmid: pmid,
          message: message,
        );

  const PmSendResult.rejected(String message)
      : this(disposition: PmSendDisposition.rejected, message: message);

  const PmSendResult.uncertain(String message)
      : this(disposition: PmSendDisposition.uncertain, message: message);

  final PmSendDisposition disposition;
  final String? pmid;
  final String? message;

  bool get isSuccess => disposition == PmSendDisposition.success;
  bool get isUncertain => disposition == PmSendDisposition.uncertain;
}
