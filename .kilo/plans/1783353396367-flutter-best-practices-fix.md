# Flutter 最佳实践修正计划

## 目标

修正审查中发现的 8 个问题，使项目完全遵循 Flutter 最佳实践和 Riverpod 惯用模式。

## 影响范围

| 文件 | 变更类型 |
|------|---------|
| `analysis_options.yaml` | 修改 - 添加 lint 规则 |
| `lib/services/formhash_service.dart` | 重构 - 去单例，改 Riverpod Notifier |
| `lib/services/http_client.dart` | 重构 - 去静态单例，注入 FormhashService |
| `lib/services/auth_service.dart` | 重构 - 去 ChangeNotifier，改纯 Riverpod Notifier |
| `lib/providers/auth_provider.dart` | 重构 - AuthNotifier 逻辑内聚，去掉 ChangeNotifier 桥接 |
| `lib/screens/home_screen.dart` | 修改 - _ForumErrorView 改 ConsumerWidget |
| `lib/screens/compose_screen.dart` | 修改 - 去未使用 import，改用 Riverpod DI |
| `lib/screens/profile_screen.dart` | 无变更（已是最佳实践） |
| `lib/widgets/quote_block.dart` | 修改 - withOpacity → withValues |
| `lib/widgets/web_avatar_html.dart` | 修改 - dart:html → package:web（如可行） |
| `lib/config/colors.dart` | 无变更（硬编码灰色属于 UI 细节，不在本次范围） |
| `lib/services/api_service.dart` | 修改 - 变量命名 lowercaseCamel |

## 步骤

### Step 1: 升级 analysis_options.yaml

替换整个文件内容为：

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - require_trailing_commas
    - prefer_const_constructors
    - prefer_const_declarations
    - unawaited_futures
    - use_super_parameters
    - sort_constructors_first
    - avoid_print
```

**验证**: `flutter analyze` 无新增 error。

---

### Step 2: FormhashService 去单例 → Riverpod Notifier

**当前问题**: `FormhashService` 使用 `factory` 单例 + `ChangeNotifier`，与 Riverpod DI 不一致。

**方案**: 用 `Notifier<String>` 替代，formhash 状态就是 `state`。

```dart
// lib/services/formhash_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FormhashNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String? value) {
    if (value != null && value.isNotEmpty && value != state) {
      state = value;
    }
  }

  void clear() => state = '';
}

final formhashProvider = NotifierProvider<FormhashNotifier, String>(
  FormhashNotifier.new,
);
```

**受影响文件**: `http_client.dart` (Step 3 一并处理)。

**验证**: `flutter analyze` 无报错。

---

### Step 3: S1HttpClient 去静态单例 → Riverpod Provider

**当前问题**: `S1HttpClient` 有 `_instance` / `resetInstance()` 静态单例，又被包一层 Riverpod Provider。

**方案**:
1. 删除 `_instance` / `resetInstance()` / `S1HttpClient._()` 私有构造
2. 改为普通构造 + `init()` 方法
3. `httpClientProvider` 改为 `AsyncProvider<S1HttpClient>`（因为 `init()` 是异步的）
4. FormhashService 注入改为 `ref.watch(formhashProvider)`

新 `S1HttpClient`:
```dart
class S1HttpClient {
  late Dio _dio;
  late PersistCookieJar _cookieJar;
  final List<DateTime> _requestTimestamps = [];
  final Ref _ref;

  S1HttpClient(this._ref);

  PersistCookieJar get cookieJar => _cookieJar;

  Future<void> init() async {
    // ... 保持原逻辑，但 FormhashService() 调用改为 _ref.read(formhashProvider)
  }

  // get / post 方法保持不变
}
```

新 Provider:
```dart
final httpClientProvider = Provider<S1HttpClient>((ref) {
  final client = S1HttpClient(ref);
  // 注意：init() 需要在 main() 中手动调用，或改为 AsyncNotifier
  return client;
});
```

**关键**: `main.dart` 中 `await S1HttpClient.instance.init()` 改为通过 ProviderContainer 初始化：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  final container = ProviderContainer();
  await container.read(httpClientProvider).init();

  EmoticonMap.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const S1App(),
    ),
  );
}
```

**受影响文件**:
- `lib/main.dart` - 改为 `ProviderContainer` + `UncontrolledProviderScope`
- `lib/screens/compose_screen.dart` - `S1HttpClient.instance` → `ref.read(httpClientProvider)`
- `lib/providers/auth_provider.dart` - `httpClientProvider` 保持不变（已是 Riverpod）
- `lib/services/auth_service.dart` - 构造函数接受 `S1HttpClient`（不变）

**验证**: `flutter analyze` 无报错，手动测试登录流程。

---

### Step 4: AuthService 去 ChangeNotifier → 纯 Dart 类

**当前问题**: `AuthService extends ChangeNotifier`，`AuthNotifier` 手动 `addListener/removeListener` 桥接，且 `dispose()` 中 `removeListener` 脆弱。

**方案**: 去掉 `extends ChangeNotifier`，将 `AuthService` 变为普通 Dart 类（纯业务逻辑层）。`AuthNotifier`（保持 `StateNotifier`）直接调用 `AuthService` 方法，在回调后自行 `state = ...` 更新。删除 `addListener/removeListener` 桥接。

关键: **不改为 AsyncNotifier**，因为会级联影响所有 `ref.watch(authStateProvider)` 的消费者从 `AuthState` 变为 `AsyncValue<AuthState>`，改动面太大。

新 `auth_service.dart`:
```dart
class AuthService {
  final S1HttpClient _httpClient;

  AuthService({required S1HttpClient httpClient}) : _httpClient = httpClient;

  User? _currentUser;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  /// 登录，返回 null 成功，否则返回错误信息
  Future<String?> login(String username, String password) async {
    final apiService = ApiService(_httpClient);
    final error = await apiService.login(username, password);
    if (error == null) {
      _isLoggedIn = true;
      _currentUser = User(uid: '', username: username);
      _fetchProfile(); // fire-and-forget
      return null;
    }
    return error;
  }

  Future<void> _fetchProfile() async {
    final apiService = ApiService(_httpClient);
    final profile = await apiService.getUserProfile();
    if (profile != null) _currentUser = profile;
  }

  Future<User?> fetchProfile() async {
    await _fetchProfile();
    return _currentUser;
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _httpClient.cookieJar.deleteAll();
  }

  Future<bool> checkSession() async {
    final apiService = ApiService(_httpClient);
    try {
      final profile = await apiService.getUserProfile();
      if (profile != null && profile.uid.isNotEmpty && profile.uid != '0') {
        _currentUser = profile;
        _isLoggedIn = true;
        return true;
      }
    } catch (_) {}
    return false;
  }
}
```

新 `auth_provider.dart` (关键变更):
```dart
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(httpClient: ref.watch(httpClientProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final ok = await _authService.checkSession();
    if (ok) {
      state = AuthState(
        isLoggedIn: true,
        username: _authService.currentUser?.username,
        user: _authService.currentUser,
      );
    }
  }

  Future<String?> login(String username, String password) async {
    final error = await _authService.login(username, password);
    if (error == null) {
      state = AuthState(
        isLoggedIn: true,
        username: _authService.currentUser?.username,
        user: _authService.currentUser,
      );
      // 稍后刷新 profile
      _authService.fetchProfile().then((user) {
        if (user != null && mounted) {
          state = state.copyWith(user: user, username: user.username);
        }
      });
    }
    return error;
  }

  Future<void> refreshProfile() async {
    final user = await _authService.fetchProfile();
    if (user != null && mounted) {
      state = state.copyWith(user: user, username: user.username);
    }
  }

  void logout() {
    _authService.logout();
    state = AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
```

**受影响文件**:
- `lib/services/auth_service.dart` - 去 ChangeNotifier，简化为纯类
- `lib/providers/auth_provider.dart` - 去 addListener/removeListener，直接调用
- 其他屏幕文件 **无需修改**（`authStateProvider` 返回类型不变）

**验证**: `flutter analyze` 无报错，手动测试登录/登出。

---

### Step 5: _ForumErrorView 改 ConsumerWidget

**当前问题**: `lib/screens/home_screen.dart:131` 使用 `ProviderScope.containerOf(context)` 反模式。

**方案**: 将 `_ForumErrorView` 从 `StatelessWidget` 改为 `ConsumerWidget`，用 `ref.read()`。

```dart
class _ForumErrorView extends ConsumerWidget {
  final Object error;
  const _ForumErrorView({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...
    FilledButton.icon(
      onPressed: () {
        if (isLogin) {
          context.push('/login');
        } else {
          ref.read(forumListProvider.notifier).refresh();
        }
      },
    );
  }
}
```

**验证**: `flutter analyze` 无报错。

---

### Step 6: 修复 quote_block.dart withOpacity

**当前问题**: `lib/widgets/quote_block.dart:18` 使用已弃用的 `withOpacity`。

**方案**:
```dart
// 之前
.withOpacity(0.5)
// 之后
.withValues(alpha: 0.5)
```

**验证**: `flutter analyze` 无 `deprecated_member_use`。

---

### Step 7: 修复 api_service.dart 变量命名

**当前问题**: `Message` / `Variables` 大写开头，违反 lowerCamelCase。

**方案**: 局部变量改为 `message` / `variables`（与函数内其他变量一致）。

涉及行: `lib/services/api_service.dart:53,57,235`。

**验证**: `flutter analyze` 无 `non_constant_identifier_names`。

---

### Step 8: 修复 compose_screen.dart 未使用 import + 直接实例化

**当前问题**:
- `import '../services/formhash_service.dart'` 未使用
- `ApiService(S1HttpClient.instance)` 直接实例化单例

**方案**:
1. 删除未使用 import
2. 改为 `ref.read(httpClientProvider)` 获取 client

**验证**: `flutter analyze` 无 `unused_import`。

---

### Step 9: web_avatar_html.dart dart:html 弃用（可选）

**当前问题**: `dart:html` 已弃用，建议迁移 `package:web` + `dart:js_interop`。

**风险**: `package:web` API 与 `dart:html` 不兼容，`HtmlElementView` 注册方式也不同。此迁移涉及 Web 平台特有逻辑，回归测试复杂。

**决策**: 本次 **跳过**，添加 `// ignore: deprecated_member_use` + `// ignore: avoid_web_libraries_in_flutter` 抑制警告。后续单独处理 Web 平台迁移。

---

## 执行顺序

```
Step 2 → Step 3 → Step 4 → Step 5 → Step 6 → Step 7 → Step 8 → Step 9 → Step 1
```

- Steps 2→3→4 是核心 DI 重构，有依赖关系，必须按序执行
- Steps 5→8 是独立小修复，可并行
- Step 1（lint 规则）**最后执行**，避免新增规则干扰重构过程中的 `flutter analyze`
- Step 10: 全局 `flutter analyze` 清理 `prefer_const_constructors` / `require_trailing_commas` 等新规则带来的 warning

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Step 3 ProviderContainer 改 main.dart 启动顺序 | 高 | init() 必须在 runApp 前 await |
| Step 4 AuthService 去 ChangeNotifier 后登录状态丢失 | 中 | AuthNotifier._init() 在构造时调用 checkSession() |
| Step 1 新 lint 规则产生大量 warning | 低 | 最后执行，一次性批量修复 |
| dart:html 迁移风险 | 高 | 本次跳过（Step 9 仅 ignore） |

## 验证清单

- [ ] `flutter analyze` 只剩 scripts/ 下的 `avoid_print`（脚本文件用 print 是合理的）
- [ ] 手动测试: 启动 → 论坛列表加载 → 登录 → 浏览帖子 → 发帖 → 退出登录
- [ ] Web 模式: `flutter run -d chrome` 正常启动
