import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_service_provider.dart';

final userProfileProvider =
    FutureProvider.autoDispose.family<User?, String>((ref, uid) async {
  return ref.watch(apiServiceProvider).getUserProfileByUid(uid);
});
