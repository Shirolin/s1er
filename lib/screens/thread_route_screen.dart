import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thread_open_intent.dart';
import '../providers/post_provider.dart';
import '../providers/reading_history_provider.dart';
import '../utils/forum_list_layout.dart';
import 'forum_list_screen.dart';
import 'thread_detail_screen.dart';

/// `/thread/:tid` 路由的宽屏适配。
///
/// 大屏直接打开帖子（首页置顶 / 最近浏览 / 分享链接等）时，帖子本身并不
/// 携带 fid。这里先用阅读历史或帖子首屏数据解析论坛 fid，再切到
/// 「论坛列表 + 详情」双栏，与从版块列表点进帖子的体验保持一致。
/// fid 未知前仍显示单栏详情；窄屏保持原样。
class ThreadRouteScreen extends ConsumerWidget {
  const ThreadRouteScreen({
    super.key,
    required this.tid,
    this.intent,
    this.fidHint,
  });

  final String tid;
  final ThreadOpenIntent? intent;

  /// 路由上携带的论坛 fid 提示（双栏左栏选帖时写入）。
  final String? fidHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shouldOpenForumThreadInPlace(MediaQuery.sizeOf(context).width)) {
      return ThreadDetailScreen(tid: tid);
    }

    final historyFid = ref.watch(readingRecordProvider(tid))?.fid;
    final liveFid = ref.watch(
      postProvider(tid).select(
        (posts) => posts.asData?.value.threadFid,
      ),
    );
    final fid = resolveThreadForumFid(
      liveFid: liveFid,
      fidHint: fidHint,
      historyFid: historyFid,
    );
    if (fid == null) return ThreadDetailScreen(tid: tid);

    return ForumListScreen(
      key: ValueKey('thread-split-$fid'),
      fid: fid,
      selectedThreadId: tid,
      selectedThreadIntent: intent,
      keepThreadRoute: true,
    );
  }
}
