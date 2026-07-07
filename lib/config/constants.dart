class S1Constants {
  static const String appName = 'S1 Client';
  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.0 Mobile/15E148 Safari/604.1';
  static const int maxRequestsPerSecond = 2;
  static const int cookieRefreshIntervalMinutes = 30;
  static const Duration cacheExpiry = Duration(minutes: 5);

  /// 识别表情包路径的特征
  static bool isEmoticon(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('static.stage1st.com/image/smiley') ||
           lowerUrl.contains('face2017');
  }
}
