import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:s1er/models/notice_item.dart';
import 'package:s1er/models/private_message_item.dart';
import 'package:s1er/providers/notice_list_provider.dart';
import 'package:s1er/providers/pm_list_provider.dart';

PmListState samplePmListState() {
  return PmListState(
    items: [
      PrivateMessageItem(
        touid: '535036',
        partnerName: 'Kiyohara_Yasuke',
        preview: '那就好',
        dateline: 1718585640,
        isOutgoing: true,
        avatarUrl: 'https://avatar.stage1st.com/000/53/50/36_avatar_small.jpg',
      ),
    ],
  );
}

NoticeListState sampleNoticeListState({
  int currentPage = 1,
  int totalPages = 3,
}) {
  return NoticeListState(
    items: [
      NoticeItem(
        id: '18830194',
        authorUid: '565047',
        authorName: 'JOJOROY',
        summary: 'JOJOROY 回复了您的帖子 Switch 2《Splatoon RAIDERS》',
        dateline: 1783659660,
        tid: '2253488',
        pid: '69899250',
        type: NoticeType.reply,
      ),
    ],
    currentPage: currentPage,
    totalPages: totalPages,
  );
}

List<Override> messagesProviderOverrides({
  PmListState? pmState,
  NoticeListState? noticeState,
}) {
  return [
    pmListProvider.overrideWith(
      () => PmListNotifier(seed: pmState ?? samplePmListState()),
    ),
    noticeListProvider.overrideWith(
      () => NoticeListNotifier(seed: noticeState ?? sampleNoticeListState()),
    ),
  ];
}
