import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/forum_tools_service.dart';
import '../services/http_client.dart';

final forumToolsServiceProvider = Provider<ForumToolsService>((ref) {
  return ForumToolsService(ref.watch(httpClientProvider));
});
