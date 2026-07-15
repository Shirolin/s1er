class ApiConfig {
  static const String baseUrl = 'https://stage1st.com/2b';
  static const String mobileApiUrl = '$baseUrl/api/mobile/index.php';
  static const String loginUrl = '$baseUrl/member.php?mod=logging&action=login';
  static const String forumPostUrl = '$baseUrl/forum.php';

  /// Discuz 回复 POST 所需的 Referer（来路校验）
  static String forumReplyReferer({
    required String fid,
    required String tid,
    String reppost = '0',
  }) =>
      '$forumPostUrl?mod=post&action=reply&fid=$fid&tid=$tid'
      '&reppost=$reppost&extra=&replysubmit=yes&mobile=2&handlekey=postform';

  /// Discuz 收藏 POST 所需的 Referer（来路校验）
  static String favoriteThreadReferer(String tid) =>
      '$forumPostUrl?mod=viewthread&tid=$tid&extra=page%3D1&mobile=2';

  static String favoriteForumReferer(String fid) =>
      '$forumPostUrl?mod=forumdisplay&fid=$fid&mobile=2';

  /// Discuz 评分 POST 所需的 Referer（来路校验）
  static String forumRateReferer(String tid, String pid) =>
      '$forumPostUrl?mod=viewthread&tid=$tid&page=0#pid$pid';

  // API module names
  static const String moduleForumIndex = 'forumindex';
  static const String moduleForumDisplay = 'forumdisplay';
  static const String moduleViewThread = 'viewthread';
  static const String moduleLogin = 'login';
  static const String moduleSendMessage = 'sendpm';
  static const String moduleMyPm = 'mypm';
  static const String moduleMyNoteList = 'mynotelist';
  static const String moduleProfile = 'profile';
  static const String moduleMyFavThread = 'myfavthread';
  static const String moduleMyFavForum = 'myfavforum';
  static const String moduleFavThread = 'favthread';
  static const String moduleFavForum = 'favforum';
  static const String moduleSendReply = 'sendreply';
  static const String moduleFriend = 'friend';

  /// 好友 Mobile API 使用 version=1（与 S1-Next 一致；实测响应 `Version:"1"`）。
  static const String friendApiVersion = '1';

  /// Discuz 每日签到插件（GET，需 formhash；会产生服务端写入）。
  static String dailyAttendanceUrl({required String formhash}) =>
      '$baseUrl/study_daily_attendance-daily_attendance.html'
      '?inajax=1&formhash=${Uri.encodeComponent(formhash)}';

  /// 小黑屋公开处罚列表（cursor 分页）。
  static String darkRoomUrl({String? cursor}) {
    final cid = cursor == null || cursor.isEmpty
        ? ''
        : '&cid=${Uri.encodeComponent(cursor)}';
    return '$forumPostUrl?mod=misc&action=showdarkroom&ajaxdata=json$cid';
  }

  static String friendsBrowserUrl(String uid) =>
      '$baseUrl/home.php?mod=space&uid=$uid&do=friend&view=me&mobile=2';

  static String darkRoomBrowserUrl() =>
      '$forumPostUrl?mod=misc&action=showdarkroom&mobile=2';

  /// Discuz 搜索（HTML）：主题 / 用户。
  static String searchForumUrl({int? page}) {
    final pageQuery = page == null ? '' : '&page=$page';
    return '$baseUrl/search.php?searchsubmit=yes&mod=forum$pageQuery';
  }

  static String searchUserUrl() =>
      '$baseUrl/search.php?searchsubmit=yes&mod=user';
}
