/// S1 资源域名统一配置
///
/// 论坛历史上换过多次资源域名，所有域名规则集中在此文件管理。
/// Flutter 端（http_client / image_viewer）和代理端（proxy_server）共享此配置。
/// 新增/修改域名只需改动此文件。
library resource_domains;

// ──────────────────────── 资源类型 ────────────────────────

enum ResourceType {
  /// API 主域名 → 走代理默认路由，需要 Cookie
  api,

  /// 需要认证的图片资源 → 走代理 /img-proxy，需要 Cookie + Referer
  authImage,

  /// 公开资源（表情包等）→ 浏览器直加载，无需认证
  publicAsset,
}

// ──────────────────────── 域名规则 ────────────────────────

class DomainRule {
  const DomainRule({
    required this.host,
    required this.type,
    this.referer,
  });

  /// 域名（精确匹配）
  final String host;

  /// 资源类型
  final ResourceType type;

  /// 自定义 Referer（仅 authImage 生效），null 时使用默认值
  final String? referer;
}

// ──────────────────────── 配置中心 ────────────────────────

class ResourceDomains {
  ResourceDomains._();

  /// 代理服务器端口
  static const int proxyPort = 19080;

  /// API 主域名（用于代理默认路由）
  static const String apiHost = 'stage1st.com';

  /// 认证 Cookie 前缀（用于过滤无关 Cookie）
  static const String cookiePrefix = 'B7Y9_2f85_';

  /// 认证图片请求的默认 Referer
  static const String defaultReferer = 'https://stage1st.com/';

  /// 域名规则表（按顺序匹配，第一个命中即生效）
  ///
  /// 新增域名时，在此处添加一行即可。
  /// 历史域名备忘：
  ///   - bbs.stage1st.com（旧主域名，含附件和表情）
  ///   - img1.stage1st.com（旧图片 CDN）
  static const List<DomainRule> rules = [
    // API
    DomainRule(host: 'stage1st.com', type: ResourceType.api),
    DomainRule(host: 'www.stage1st.com', type: ResourceType.api),

    // 需认证的图片
    DomainRule(host: 'img.stage1st.com', type: ResourceType.authImage),

    // 公开资源（表情包等）
    DomainRule(host: 'static.stage1st.com', type: ResourceType.publicAsset),
  ];

  // ──────────────────────── 查询方法 ────────────────────────

  /// 根据 host 查找匹配的规则，未匹配返回 null
  static DomainRule? match(String host) {
    for (final rule in rules) {
      if (rule.host == host) return rule;
    }
    return null;
  }

  /// 该 host 是否需要通过 Dio 加载（带 Cookie）
  static bool requiresAuth(String host) {
    final rule = match(host);
    return rule?.type == ResourceType.api ||
        rule?.type == ResourceType.authImage;
  }

  /// 该 host 是否需要走代理（Web 端 CORS 限制）
  static bool requiresProxy(String host) {
    final rule = match(host);
    return rule?.type == ResourceType.api ||
        rule?.type == ResourceType.authImage;
  }

  /// 获取认证图片的 Referer
  static String getReferer(String host) {
    final rule = match(host);
    return rule?.referer ?? defaultReferer;
  }
}
