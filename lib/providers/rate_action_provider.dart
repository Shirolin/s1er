import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rate_form.dart';
import 'api_service_provider.dart';

typedef RateTarget = (String tid, String pid);

final rateFormProvider =
    FutureProvider.autoDispose.family<RateFormOptions, RateTarget>(
  (ref, target) async {
    final (tid, pid) = target;
    return ref.watch(apiServiceProvider).fetchRateForm(tid: tid, pid: pid);
  },
);

class RateActionController {
  RateActionController(this._ref, this.target);

  final Ref _ref;
  final RateTarget target;

  Future<String?> submit({
    required String score1,
    required String reason,
    required bool notifyAuthor,
    RateFormOptions? form,
  }) {
    final (tid, pid) = target;
    return _ref.read(apiServiceProvider).submitRate(
          tid: tid,
          pid: pid,
          score1: score1,
          reason: reason,
          notifyAuthor: notifyAuthor,
          form: form,
        );
  }
}

final rateActionControllerProvider =
    Provider.family<RateActionController, RateTarget>((ref, target) {
  return RateActionController(ref, target);
});
