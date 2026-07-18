import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_form.dart';
import 'api_service_provider.dart';

typedef ReportTarget = ({
  String tid,
  String pid,
  String? fid,
  int page,
});

final reportFormProvider =
    FutureProvider.autoDispose.family<ReportFormOptions, ReportTarget>(
  (ref, target) => ref.watch(apiServiceProvider).fetchReportForm(
        tid: target.tid,
        pid: target.pid,
        fid: target.fid,
        page: target.page,
      ),
);

class ReportActionController {
  ReportActionController(this._ref, this.target);

  final Ref _ref;
  final ReportTarget target;

  Future<String?> submit({
    required ReportFormOptions form,
    required String reason,
    required String message,
  }) {
    return _ref.read(apiServiceProvider).submitReport(
          tid: target.tid,
          pid: target.pid,
          fid: target.fid,
          reason: reason,
          message: message,
          form: form,
        );
  }
}

final reportActionControllerProvider = Provider.autoDispose
    .family<ReportActionController, ReportTarget>((ref, target) {
  return ReportActionController(ref, target);
});
