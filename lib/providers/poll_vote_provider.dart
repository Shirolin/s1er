import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_service_provider.dart';

class PollVoteController {
  PollVoteController(this._ref, this.tid);

  final Ref _ref;
  final String tid;

  Future<String?> submit(List<String> optionIds) {
    return _ref.read(apiServiceProvider).votePoll(
          tid: tid,
          optionIds: optionIds,
        );
  }
}

final pollVoteControllerProvider =
    Provider.autoDispose.family<PollVoteController, String>((ref, tid) {
  return PollVoteController(ref, tid);
});
