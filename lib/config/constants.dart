class S1Constants {
  static const String appName = 'S1 Client';
  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.0 Mobile/15E148 Safari/604.1';
  static const int maxRequestsPerSecond = 2;
  static const int cookieRefreshIntervalMinutes = 30;
  static const Duration cacheExpiry = Duration(minutes: 5);

  /// 帖子详情页每页帖数的兜底值。
  /// 权威来源是 API 的 `ppp` 字段（viewthread，实际为 40）；仅在拿不到
  /// API 值时（如帖子列表只有列表数据、无 `ppp`）使用此兜底值。
  /// 注意：勿与 forumdisplay 的 `tpp`(=50，主题列表每页数) 混用。
  static const int postsPerPageFallback = 40;

  /// 图片磁盘缓存总字节上限（与 [S1ImageCache.maxNrOfCacheObjects] 并存）。
  static const int maxImageCacheBytes = 100 * 1024 * 1024;

  /// Inline 图片解码宽度 clamp（物理像素）。
  static const int inlineImageDecodeMinPx = 200;
  static const int inlineImageDecodeMaxPx = 1600;

  /// 识别表情包路径的特征
  static bool isEmoticon(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('static.stage1st.com/image/smiley') ||
           lowerUrl.contains('face2017');
  }
}
