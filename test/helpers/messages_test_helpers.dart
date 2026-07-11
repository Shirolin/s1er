import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:s1_app/models/notice_item.dart';
import 'package:s1_app/models/private_message_item.dart';
import 'package:s1_app/providers/notice_list_provider.dart';
import 'package:s1_app/providers/pm_list_provider.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';

ApiService _testApiService() =>
    ApiService(S1HttpClient.test(ProviderContainer(), Dio()));

PmListState samplePmListState() {
  return PmListState(
    items: [
      PrivateMessageItem(
        touid: '535036',
        partnerName: 'Kiyohara_Yasuke',
        preview: '那就好',
        dateline: 1718585640,
        isOutgoing: true,
        avatarUrl:
            'https://avatar.stage1st.com/000/53/50/36_avatar_small.jpg',
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
  AsyncValue<PmListState>? pmAsync,
  AsyncValue<NoticeListState>? noticeAsync,
}) {
  return [
    pmListProvider.overrideWith(
      (ref) => PmListNotifier(
        apiService: _testApiService(),
        initialState: pmAsync ?? AsyncValue.data(samplePmListState()),
      ),
    ),
    noticeListProvider.overrideWith(
      (ref) => NoticeListNotifier(
        apiService: _testApiService(),
        initialState:
            noticeAsync ?? AsyncValue.data(sampleNoticeListState()),
      ),
    ),
  ];
}
