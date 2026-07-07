import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cookie_jar/cookie_jar.dart' as cjar;
import '../providers/auth_provider.dart';
import '../services/http_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Web 端登录使用的控制器与状态
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) async {
              setState(() {
                _isLoading = false;
              });

              // 1. 注入 CSS 隐藏网页上乱七八糟的页眉、页脚、下载 App 广告，让界面更加沉浸式
              await _controller.runJavaScript("""
                (function() {
                  var style = document.createElement('style');
                  style.type = 'text/css';
                  style.innerHTML = `
                    .header, header, footer, .footer, .footer_wrap, 
                    .banner, .app-download, .download-bar, 
                    #header, #footer { display: none !important; }
                    body { padding-top: 10px !important; padding-bottom: 10px !important; }
                  `;
                  document.getElementsByTagName('head')[0].appendChild(style);
                })();
              """);

              // 2. 扫描并同步 Cookie。一旦检测到登录成功后的 Session 凭证（例如以 auth 结尾的 Cookie 字段有值）
              final cookieManager = WebViewCookieManager();
              final cookies = await cookieManager.getCookies(
                domain: Uri.parse(url),
              );
              
              bool hasAuth = false;
              String username = 'S1User';

              for (final cookie in cookies) {
                if (cookie.name.endsWith('auth') && cookie.value.isNotEmpty) {
                  hasAuth = true;
                }
                if (cookie.name.endsWith('username') && cookie.value.isNotEmpty) {
                  username = Uri.decodeComponent(cookie.value);
                }
              }

              if (hasAuth) {
                // 将 WebView 中的所有 Cookie 同步导入到底层的 S1HttpClient 的 PersistCookieJar 里
                final List<cjar.Cookie> newCookies = cookies.map((c) {
                  final newC = cjar.Cookie(c.name, c.value)
                    ..domain = c.domain
                    ..path = c.path;
                  return newC;
                }).toList();
                
                await ref.read(httpClientProvider).cookieJar.saveFromResponse(
                  Uri.parse(url),
                  newCookies,
                );

                // 标志登录成功并返回主页
                ref.read(authStateProvider.notifier).setLoggedIn(username);
                if (mounted) {
                  context.go('/');
                }
              }
            },
          ),
        );

      // 将已有的登录 cookie 注入 WebView，使已登录用户无需重新登录
      ref.read(httpClientProvider).syncCookiesToWebView().then((_) {
        _controller.loadRequest(Uri.parse(
            'https://stage1st.com/2b/member.php?mod=logging&action=login&mobile=2',),);
      });
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleWebLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '用户名和密码不能为空';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await ref.read(authStateProvider.notifier).login(username, password);

    if (!mounted) return;

    if (error == null) {
      context.go('/');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('登录 Stage1st (Web)'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '欢迎回来',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '登录您的 Stage1st 账号',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14,),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        prefixIcon: Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleWebLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 Stage1st'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
