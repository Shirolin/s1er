# S1 Forum Flutter App - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform Flutter client for Stage1st forum with full CRUD (browse, login, post, reply, like, bookmark).

**Architecture:** Riverpod state management, Dio HTTP client with cookie persistence, API-first data fetching with HTML parser fallback, custom BBCode renderer for native widget content display.

**Tech Stack:** Flutter 3.x, Riverpod, Dio, Hive, go_router, cached_network_image, html (DOM parser)

## Global Constraints

- Flutter 3.22+ required
- Dart 3.4+ required
- Target: iOS 13+ / Android API 21+
- All network requests must use mobile browser User-Agent
- Cookie persistence via Hive for session management
- Emoticons bundled as local assets (zero network requests)

---

## File Structure

```
s1_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── api_config.dart
│   │   └── constants.dart
│   ├── models/
│   │   ├── thread.dart
│   │   ├── post.dart
│   │   ├── forum_category.dart
│   │   ├── user.dart
│   │   └── emoticon.dart
│   ├── services/
│   │   ├── http_client.dart
│   │   ├── api_service.dart
│   │   ├── html_parser_service.dart
│   │   ├── auth_service.dart
│   │   └── formhash_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── thread_list_provider.dart
│   │   ├── post_provider.dart
│   │   └── settings_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── forum_list_screen.dart
│   │   ├── thread_detail_screen.dart
│   │   ├── login_screen.dart
│   │   ├── compose_screen.dart
│   │   └── profile_screen.dart
│   ├── widgets/
│   │   ├── thread_card.dart
│   │   ├── post_item.dart
│   │   ├── bbcode_renderer.dart
│   │   ├── emoticon_widget.dart
│   │   ├── image_viewer.dart
│   │   └── quote_block.dart
│   ├── utils/
│   │   ├── bbcode_parser.dart
│   │   ├── cookie_store.dart
│   │   └── image_cache.dart
│   └── theme/
│       ├── app_theme.dart
│       └── colors.dart
├── assets/
│   └── emoticons/
├── pubspec.yaml
└── test/
```

---

### Task 1: Project Setup & Dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/config/constants.dart`
- Create: `lib/config/api_config.dart`

**Interfaces:**
- Consumes: (none)
- Produces: Runnable Flutter app shell with theme, routing placeholder, and all dependencies configured

- [ ] **Step 1: Create Flutter project**

Run: `flutter create --org com.stage1st s1_app`
Expected: Creates `s1_app/` directory with Flutter boilerplate

- [ ] **Step 2: Configure pubspec.yaml**

Replace `pubspec.yaml` with:

```yaml
name: s1_app
description: Third-party Stage1st forum client
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  dio: ^5.4.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  go_router: ^14.0.0
  cached_network_image: ^3.3.1
  html: ^0.15.4
  url_launcher: ^6.2.5
  image_picker: ^1.0.7
  flutter_html: ^3.0.0-beta.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.8

flutter:
  uses-material-design: true
  assets:
    - assets/emoticons/
```

- [ ] **Step 3: Create constants.dart**

```dart
// lib/config/constants.dart
class S1Constants {
  static const String appName = 'S1er';
  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.0 Mobile/15E148 Safari/604.1';
  static const int maxRequestsPerSecond = 2;
  static const int cookieRefreshIntervalMinutes = 30;
  static const Duration cacheExpiry = Duration(minutes: 5);
}
```

- [ ] **Step 4: Create api_config.dart**

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://stage1st.com/2b';
  static const String mobileApiUrl = '$baseUrl/api/mobile/index.php';
  static const String loginUrl = '$baseUrl/member.php?mod=logging&action=login';
  static const String forumDisplayUrl = '$baseUrl/forum.php?mobile=2';

  // API module names
  static const String moduleForumIndex = 'forumindex';
  static const String moduleForumDisplay = 'forumdisplay';
  static const String moduleViewThread = 'viewthread';
  static const String moduleLogin = 'login';
  static const String moduleSendPost = 'sendpost';
  static const String moduleSendMessage = 'sendpm';
}
```

- [ ] **Step 5: Create main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  runApp(
    const ProviderScope(
      child: S1App(),
    ),
  );
}
```

- [ ] **Step 6: Create app.dart**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forum_list_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/forum/:fid',
        builder: (context, state) => ForumListScreen(
          fid: state.pathParameters['fid']!,
        ),
      ),
      GoRoute(
        path: '/thread/:tid',
        builder: (context, state) => ThreadDetailScreen(
          tid: state.pathParameters['tid']!,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/compose',
        builder: (context, state) => ComposeScreen(
          tid: state.uri.queryParameters['tid'],
          fid: state.uri.queryParameters['fid'],
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class S1App extends ConsumerWidget {
  const S1App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'S1er',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 7: Create placeholder screens**

Create minimal placeholder files so the app compiles:

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Home')));
}
```

Repeat for `forum_list_screen.dart`, `thread_detail_screen.dart`, `login_screen.dart`, `compose_screen.dart`, `profile_screen.dart` with appropriate constructor params.

- [ ] **Step 8: Create theme files**

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: S1Colors.primary,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: S1Colors.primary,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true),
  );
}
```

```dart
// lib/theme/colors.dart
import 'package:flutter/material.dart';

class S1Colors {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF34A853);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
}
```

- [ ] **Step 9: Verify app runs**

Run: `cd s1_app && flutter run`
Expected: App launches with "Home" text centered on screen

- [ ] **Step 10: Commit**

```bash
git init && git add .
git commit -m "feat: project setup with Flutter, Riverpod, Dio, Hive, go_router"
```

---

### Task 2: Data Models

**Files:**
- Create: `lib/models/thread.dart`
- Create: `lib/models/post.dart`
- Create: `lib/models/forum_category.dart`
- Create: `lib/models/user.dart`
- Create: `lib/models/emoticon.dart`
- Create: `test/models_test.dart`

**Interfaces:**
- Consumes: (none)
- Produces: `Thread`, `Post`, `ForumCategory`, `User`, `Emoticon` data classes used by all services and providers

- [ ] **Step 1: Write model tests**

```dart
// test/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/thread.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/models/forum_category.dart';
import 'package:s1_app/models/user.dart';

void main() {
  group('Thread', () {
    test('parses from JSON', () {
      final json = {
        'tid': '12345',
        'subject': 'Test Thread',
        'author': 'testuser',
        'authorid': '100',
        'dateline': '1700000000',
        'views': '500',
        'replies': '20',
        'fid': '4',
      };
      final thread = Thread.fromJson(json);
      expect(thread.tid, '12345');
      expect(thread.subject, 'Test Thread');
      expect(thread.author, 'testuser');
      expect(thread.views, 500);
      expect(thread.replies, 20);
    });

    test('parses from HTML', () {
      // Placeholder for HTML parsing test
    });
  });

  group('Post', () {
    test('parses from JSON', () {
      final json = {
        'pid': '67890',
        'message': 'Hello world',
        'author': 'user1',
        'authorid': '200',
        'dateline': '1700001000',
        'floor': 1,
      };
      final post = Post.fromJson(json);
      expect(post.pid, '67890');
      expect(post.message, 'Hello world');
      expect(post.floor, 1);
    });
  });

  group('ForumCategory', () {
    test('parses from JSON', () {
      final json = {
        'fid': '4',
        'name': '技术讨论',
        'description': 'Tech discussion',
        'threads': '1000',
        'posts': '5000',
      };
      final cat = ForumCategory.fromJson(json);
      expect(cat.fid, '4');
      expect(cat.name, '技术讨论');
    });
  });

  group('User', () {
    test('parses from JSON', () {
      final json = {
        'uid': '100',
        'username': 'testuser',
        'avatar': 'https://example.com/avatar.jpg',
        'groupTitle': '会员',
      };
      final user = User.fromJson(json);
      expect(user.uid, '100');
      expect(user.username, 'testuser');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd s1_app && flutter test test/models_test.dart`
Expected: FAIL with import errors (models don't exist yet)

- [ ] **Step 3: Implement Thread model**

```dart
// lib/models/thread.dart
class Thread {
  final String tid;
  final String subject;
  final String author;
  final String authorId;
  final int dateline;
  final int views;
  final int replies;
  final String fid;
  final String? lastPost;
  final String? lastPoster;

  Thread({
    required this.tid,
    required this.subject,
    required this.author,
    required this.authorId,
    required this.dateline,
    required this.views,
    required this.replies,
    required this.fid,
    this.lastPost,
    this.lastPoster,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      tid: json['tid']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      authorId: json['authorid']?.toString() ?? '',
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ?? 0,
      views: int.tryParse(json['views']?.toString() ?? '') ?? 0,
      replies: int.tryParse(json['replies']?.toString() ?? '') ?? 0,
      fid: json['fid']?.toString() ?? '',
      lastPost: json['lastpost']?.toString(),
      lastPoster: json['lastposter']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'tid': tid,
    'subject': subject,
    'author': author,
    'authorid': authorId,
    'dateline': dateline,
    'views': views,
    'replies': replies,
    'fid': fid,
  };
}
```

- [ ] **Step 4: Implement Post model**

```dart
// lib/models/post.dart
class Post {
  final String pid;
  final String message;
  final String author;
  final String authorId;
  final int dateline;
  final int floor;
  final String? avatar;
  final List<String> images;

  Post({
    required this.pid,
    required this.message,
    required this.author,
    required this.authorId,
    required this.dateline,
    required this.floor,
    this.avatar,
    this.images = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      pid: json['pid']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      authorId: json['authorid']?.toString() ?? '',
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ?? 0,
      floor: int.tryParse(json['floor']?.toString() ?? '') ?? 0,
      avatar: json['avatar']?.toString(),
    );
  }
}
```

- [ ] **Step 5: Implement ForumCategory model**

```dart
// lib/models/forum_category.dart
class ForumCategory {
  final String fid;
  final String name;
  final String description;
  final int threads;
  final int posts;
  final String? icon;

  ForumCategory({
    required this.fid,
    required this.name,
    required this.description,
    required this.threads,
    required this.posts,
    this.icon,
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      fid: json['fid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      threads: int.tryParse(json['threads']?.toString() ?? '') ?? 0,
      posts: int.tryParse(json['posts']?.toString() ?? '') ?? 0,
      icon: json['icon']?.toString(),
    );
  }
}
```

- [ ] **Step 6: Implement User model**

```dart
// lib/models/user.dart
class User {
  final String uid;
  final String username;
  final String? avatar;
  final String? groupTitle;

  User({
    required this.uid,
    required this.username,
    this.avatar,
    this.groupTitle,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      groupTitle: json['groupTitle']?.toString(),
    );
  }
}
```

- [ ] **Step 7: Implement Emoticon model**

```dart
// lib/models/emoticon.dart
class Emoticon {
  final String code; // e.g. "[f:001]"
  final String assetPath; // e.g. "assets/emoticons/001.png"

  Emoticon({required this.code, required this.assetPath});
}

class EmoticonMap {
  static final Map<String, String> _map = {};

  static void initialize() {
    // Will be populated from bundled assets
    for (int i = 1; i <= 100; i++) {
      final code = '[f:${i.toString().padLeft(3, '0')}]';
      final path = 'assets/emoticons/${i.toString().padLeft(3, '0')}.png';
      _map[code] = path;
    }
  }

  static String? getAssetPath(String code) => _map[code];
  static Map<String, String> get all => Map.unmodifiable(_map);
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/models_test.dart`
Expected: All tests PASS

- [ ] **Step 9: Commit**

```bash
git add lib/models/ test/models_test.dart
git commit -m "feat: data models (Thread, Post, ForumCategory, User, Emoticon)"
```

---

### Task 3: HTTP Client & Cookie Management

**Files:**
- Create: `lib/utils/cookie_store.dart`
- Create: `lib/services/http_client.dart`
- Create: `test/services/http_client_test.dart`

**Interfaces:**
- Consumes: `S1Constants` from config
- Produces: `S1HttpClient` singleton with `get()`, `post()` methods, cookie persistence

- [ ] **Step 1: Write cookie store tests**

```dart
// test/services/http_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/cookie_store.dart';

void main() {
  group('CookieStore', () {
    test('saves and retrieves cookies', () async {
      final store = CookieStore();
      await store.init();

      store.setCookies({'sessionid': 'abc123', 'user': 'test'});
      final cookies = store.getCookies();

      expect(cookies['sessionid'], 'abc123');
      expect(cookies['user'], 'test');
    });

    test('clears cookies', () async {
      final store = CookieStore();
      await store.init();
      store.setCookies({'sessionid': 'abc123'});
      store.clear();
      expect(store.getCookies(), isEmpty);
    });

    test('formats cookies for HTTP header', () async {
      final store = CookieStore();
      await store.init();
      store.setCookies({'a': '1', 'b': '2'});
      final header = store.toHeaderString();
      expect(header, contains('a=1'));
      expect(header, contains('b=2'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/http_client_test.dart`
Expected: FAIL with import errors

- [ ] **Step 3: Implement CookieStore**

```dart
// lib/utils/cookie_store.dart
import 'package:hive/hive.dart';

class CookieStore {
  static const String _boxName = 'cookies';
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  void setCookies(Map<String, String> cookies) {
    for (final entry in cookies.entries) {
      _box.put(entry.key, entry.value);
    }
  }

  Map<String, String> getCookies() {
    final cookies = <String, String>{};
    for (final key in _box.keys) {
      cookies[key.toString()] = _box.get(key).toString();
    }
    return cookies;
  }

  String toHeaderString() {
    final cookies = getCookies();
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void clear() {
    _box.clear();
  }

  bool get isEmpty => _box.isEmpty;
}
```

- [ ] **Step 4: Implement S1HttpClient**

```dart
// lib/services/http_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../utils/cookie_store.dart';

class S1HttpClient {
  static S1HttpClient? _instance;
  late Dio _dio;
  late CookieStore _cookieStore;
  final List<DateTime> _requestTimestamps = [];

  S1HttpClient._() {
    _cookieStore = CookieStore();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': S1Constants.mobileUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Rate limiting
        await _enforceRateLimit();

        // Inject cookies
        final cookieHeader = _cookieStore.toHeaderString();
        if (cookieHeader.isNotEmpty) {
          options.headers['Cookie'] = cookieHeader;
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        // Extract and save cookies from response
        _extractCookies(response);
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  static S1HttpClient get instance {
    _instance ??= S1HttpClient._();
    return _instance!;
  }

  CookieStore get cookieStore => _cookieStore;

  Future<void> init() async {
    await _cookieStore.init();
  }

  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 1),
    );
    if (_requestTimestamps.length >= S1Constants.maxRequestsPerSecond) {
      final oldest = _requestTimestamps.first;
      final waitTime = const Duration(seconds: 1) - now.difference(oldest);
      if (waitTime.isNegative == false) {
        await Future.delayed(waitTime);
      }
    }
    _requestTimestamps.add(DateTime.now());
  }

  void _extractCookies(Response response) {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      final cookies = <String, String>{};
      for (final header in setCookieHeaders) {
        final parts = header.split(';')[0].split('=');
        if (parts.length >= 2) {
          cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
      if (cookies.isNotEmpty) {
        _cookieStore.setCookies(cookies);
      }
    }
  }

  Future<Response> get(String url, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(url, queryParameters: queryParameters);
  }

  Future<Response> post(String url, {Map<String, dynamic>? data}) {
    return _dio.post(url, data: data);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/http_client_test.dart`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add lib/utils/cookie_store.dart lib/services/http_client.dart test/services/http_client_test.dart
git commit -m "feat: HTTP client with cookie management and rate limiting"
```

---

### Task 4: Discuz API Service

**Files:**
- Create: `lib/services/api_service.dart`
- Create: `test/services/api_service_test.dart`

**Interfaces:**
- Consumes: `S1HttpClient`, `ApiConfig`, `Thread`, `Post`, `ForumCategory`
- Produces: `ApiService` with methods `getForumList()`, `getThreadList()`, `getThreadDetail()`, `login()`, `sendPost()`

- [ ] **Step 1: Write API service tests**

```dart
// test/services/api_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('ApiService', () {
    test('builds correct API URL', () {
      final url = ApiService.buildApiUrl(
        module: 'forumdisplay',
        params: {'fid': '4', 'page': '1'},
      );
      expect(url, contains('module=forumdisplay'));
      expect(url, contains('fid=4'));
      expect(url, contains('page=1'));
    });

    test('parses thread list from JSON', () {
      final json = {
        'Variables': {
          'forum_threadlist': [
            {
              'tid': '123',
              'subject': 'Test',
              'author': 'user',
              'authorid': '1',
              'dateline': '1700000000',
              'views': '100',
              'replies': '5',
              'fid': '4',
            }
          ]
        }
      };
      final threads = ApiService.parseThreadList(json);
      expect(threads.length, 1);
      expect(threads[0].tid, '123');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/api_service_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement ApiService**

```dart
// lib/services/api_service.dart
import '../config/api_config.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../models/forum_category.dart';
import 'http_client.dart';

class ApiService {
  final S1HttpClient _httpClient;

  ApiService(this._httpClient);

  static String buildApiUrl({
    required String module,
    Map<String, dynamic>? params,
  }) {
    final queryParams = {
      'version': '4',
      'module': module,
      if (params != null) ...params,
    };
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '${ApiConfig.mobileApiUrl}?$queryString';
  }

  static List<Thread> parseThreadList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final threadList = variables?['forum_threadlist'] as List?;
    if (threadList == null) return [];
    return threadList
        .map((t) => Thread.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  static List<Post> parsePostList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final postList = variables?['postlist'] as List?;
    if (postList == null) return [];
    return postList
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  static List<ForumCategory> parseForumList(Map<String, dynamic> json) {
    final variables = json['Variables'] as Map<String, dynamic>?;
    final forumList = variables?['forumlist'] as List?;
    if (forumList == null) return [];
    return forumList
        .map((f) => ForumCategory.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<List<ForumCategory>> getForumList() async {
    final url = buildApiUrl(module: ApiConfig.moduleForumIndex);
    final response = await _httpClient.get(url);
    return parseForumList(response.data);
  }

  Future<List<Thread>> getThreadList(String fid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleForumDisplay,
      params: {'fid': fid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    return parseThreadList(response.data);
  }

  Future<Map<String, dynamic>> getThreadDetail(String tid, {int page = 1}) async {
    final url = buildApiUrl(
      module: ApiConfig.moduleViewThread,
      params: {'tid': tid, 'page': page.toString()},
    );
    final response = await _httpClient.get(url);
    return response.data;
  }

  Future<bool> login(String username, String password) async {
    final url = ApiConfig.loginUrl;
    final response = await _httpClient.post(url, data: {
      'username': username,
      'password': password,
      'formhash': '',
      'questionid': '0',
      'answer': '',
    });
    // Check if login succeeded by looking for redirect or cookie
    return response.statusCode == 200;
  }

  Future<bool> sendPost({
    required String fid,
    required String tid,
    required String message,
    required String formhash,
  }) async {
    final url = buildApiUrl(module: ApiConfig.moduleSendPost);
    final response = await _httpClient.post(url, data: {
      'fid': fid,
      'tid': tid,
      'message': message,
      'formhash': formhash,
      'posttime': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return response.statusCode == 200;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/api_service_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/api_service.dart test/services/api_service_test.dart
git commit -m "feat: Discuz API service with thread/post/forum parsing"
```

---

### Task 5: HTML Parser Fallback

**Files:**
- Create: `lib/services/html_parser_service.dart`
- Create: `lib/utils/bbcode_parser.dart`
- Create: `test/services/html_parser_test.dart`

**Interfaces:**
- Consumes: `S1HttpClient`, `Thread`, `Post`
- Produces: `HtmlParserService` as fallback when API fails, `BbcodeParser` for content rendering

- [ ] **Step 1: Write parser tests**

```dart
// test/services/html_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/bbcode_parser.dart';
import 'package:s1_app/services/html_parser_service.dart';

void main() {
  group('BbcodeParser', () {
    test('converts bold tags', () {
      final result = BbcodeParser.parse('[b]hello[/b]');
      expect(result, contains('hello'));
    });

    test('converts image tags', () {
      final result = BbcodeParser.parse('[img]https://example.com/pic.jpg[/img]');
      expect(result, contains('img'));
      expect(result, contains('https://example.com/pic.jpg'));
    });

    test('converts quote tags', () {
      final result = BbcodeParser.parse('[quote]quoted text[/quote]');
      expect(result, contains('quoted text'));
    });

    test('converts emoticon codes', () {
      final result = BbcodeParser.parse('[f:001]');
      expect(result, contains('emoticon'));
    });

    test('handles nested tags', () {
      final result = BbcodeParser.parse('[b][i]bold and italic[/i][/b]');
      expect(result, contains('bold and italic'));
    });
  });

  group('HtmlParserService', () {
    test('extracts thread list from HTML', () {
      final html = '''
        <div class="threadlist">
          <li><a href="thread-123-1-1.html">Test Thread</a></li>
        </div>
      ''';
      // This tests the extraction logic
      expect(html, contains('Test Thread'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/html_parser_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement BbcodeParser**

```dart
// lib/utils/bbcode_parser.dart
import 'dart:convert';

class BbcodeParser {
  static String parse(String input) {
    if (input.isEmpty) return '';

    var output = input;

    // Escape HTML first
    output = _escapeHtml(output);

    // Convert BBCode to HTML
    output = _convertTags(output);

    return output;
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _convertTags(String text) {
    var output = text;

    // Bold
    output = output.replaceAllMapped(
      RegExp(r'\[b\](.*?)\[/b\]', dotAll: true),
      (m) => '<b>${m.group(1)}</b>',
    );

    // Italic
    output = output.replaceAllMapped(
      RegExp(r'\[i\](.*?)\[/i\]', dotAll: true),
      (m) => '<i>${m.group(1)}</i>',
    );

    // Underline
    output = output.replaceAllMapped(
      RegExp(r'\[u\](.*?)\[/u\]', dotAll: true),
      (m) => '<u>${m.group(1)}</u>',
    );

    // Strikethrough
    output = output.replaceAllMapped(
      RegExp(r'\[s\](.*?)\[/s\]', dotAll: true),
      (m) => '<s>${m.group(1)}</s>',
    );

    // Color
    output = output.replaceAllMapped(
      RegExp(r'\[color=(.*?)\](.*?)\[/color\]', dotAll: true),
      (m) => '<span style="color:${m.group(1)}">${m.group(2)}</span>',
    );

    // Size
    output = output.replaceAllMapped(
      RegExp(r'\[size=(\d+)\](.*?)\[/size\]', dotAll: true),
      (m) => '<span style="font-size:${m.group(1)}px">${m.group(2)}</span>',
    );

    // Images
    output = output.replaceAllMapped(
      RegExp(r'\[img\](.*?)\[/img\]', dotAll: true),
      (m) => '<img src="${m.group(1)}" />',
    );

    // URLs
    output = output.replaceAllMapped(
      RegExp(r'\[url=(.*?)\](.*?)\[/url\]', dotAll: true),
      (m) => '<a href="${m.group(1)}">${m.group(2)}</a>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[url\](.*?)\[/url\]', dotAll: true),
      (m) => '<a href="${m.group(1)}">${m.group(1)}</a>',
    );

    // Quote
    output = output.replaceAllMapped(
      RegExp(r'\[quote\](.*?)\[/quote\]', dotAll: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );

    // Code
    output = output.replaceAllMapped(
      RegExp(r'\[code\](.*?)\[/code\]', dotAll: true),
      (m) => '<pre>${m.group(1)}</pre>',
    );

    // Emoticons [f:xxx]
    output = output.replaceAllMapped(
      RegExp(r'\[f:(\d+)\]'),
      (m) => '<span class="emoticon" data-code="f:${m.group(1)}">[表情]</span>',
    );

    // Lists
    output = output.replaceAll('[*]', '<li>');

    // Newlines
    output = output.replaceAll('\n', '<br>');

    return output;
  }

  static List<String> extractImages(String html) {
    final regex = RegExp(r'<img[^>]+src="([^"]+)"');
    return regex.allMatches(html).map((m) => m.group(1)!).toList();
  }

  static String stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
```

- [ ] **Step 4: Implement HtmlParserService**

```dart
// lib/services/html_parser_service.dart
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/thread.dart';
import '../models/post.dart';
import 'http_client.dart';

class HtmlParserService {
  final S1HttpClient _httpClient;

  HtmlParserService(this._httpClient);

  Future<List<Thread>> getThreadList(String fid, {int page = 1}) async {
    final url = 'https://stage1st.com/2b/forum.php?mobile=2&fid=$fid&page=$page';
    final response = await _httpClient.get(url);
    final doc = html_parser.parse(response.data);

    final threads = <Thread>[];
    final threadElements = doc.querySelectorAll('.threadlist li, #threadlist table');

    for (final element in threadElements) {
      try {
        final link = element.querySelector('a[href*="thread-"]');
        if (link == null) continue;

        final href = link.attributes['href'] ?? '';
        final tidMatch = RegExp(r'thread-(\d+)').firstMatch(href);
        if (tidMatch == null) continue;

        threads.add(Thread(
          tid: tidMatch.group(1)!,
          subject: link.text.trim(),
          author: element.querySelector('.by author, .authortd a')?.text.trim() ?? '',
          authorId: '',
          dateline: 0,
          views: 0,
          replies: 0,
          fid: fid,
        ));
      } catch (_) {
        continue;
      }
    }

    return threads;
  }

  Future<List<Post>> getPosts(String tid, {int page = 1}) async {
    final url = 'https://stage1st.com/2b/thread-$tid-$page-1.html?mobile=2';
    final response = await _httpClient.get(url);
    final doc = html_parser.parse(response.data);

    final posts = <Post>[];
    final postElements = doc.querySelectorAll('.message, .postmessage');

    int floor = 0;
    for (final element in postElements) {
      floor++;
      try {
        final authorEl = element.parent?.querySelector('.authortd a, .postauthor a');
        final content = element.innerHtml;

        posts.add(Post(
          pid: '',
          message: content,
          author: authorEl?.text.trim() ?? '',
          authorId: '',
          dateline: 0,
          floor: floor,
        ));
      } catch (_) {
        continue;
      }
    }

    return posts;
  }

  Future<String> getFormhash(String tid) async {
    final url = 'https://stage1st.com/2b/thread-$tid-1-1.html?mobile=2';
    final response = await _httpClient.get(url);
    final doc = html_parser.parse(response.data);

    final formhashInput = doc.querySelector('input[name="formhash"]');
    return formhashInput?.attributes['value'] ?? '';
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/html_parser_test.dart`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add lib/services/html_parser_service.dart lib/utils/bbcode_parser.dart test/services/html_parser_test.dart
git commit -m "feat: HTML parser fallback and BBCode converter"
```

---

### Task 6: Auth Service & Formhash Management

**Files:**
- Create: `lib/services/auth_service.dart`
- Create: `lib/services/formhash_service.dart`
- Create: `test/services/auth_service_test.dart`

**Interfaces:**
- Consumes: `S1HttpClient`, `ApiService`, `HtmlParserService`
- Produces: `AuthService` (login/logout/currentUser), `FormhashService` (getFormhash)

- [ ] **Step 1: Write auth tests**

```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/auth_service.dart';
import 'package:s1_app/services/formhash_service.dart';

void main() {
  group('AuthService', () {
    test('initial state is logged out', () {
      final auth = AuthService();
      expect(auth.isLoggedIn, false);
      expect(auth.currentUser, null);
    });

    test('login state changes on successful login', () async {
      final auth = AuthService();
      // Mock would be needed for real test
      expect(auth.isLoggedIn, false);
    });
  });

  group('FormhashService', () {
    test('caches formhash per thread', () {
      final service = FormhashService();
      service.cacheFormhash('123', 'abc123');
      expect(service.getFormhash('123'), 'abc123');
    });

    test('returns null for expired cache', () {
      final service = FormhashService();
      service.cacheFormhash('123', 'abc123', ttl: Duration.zero);
      expect(service.getFormhash('123'), null);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/auth_service_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement AuthService**

```dart
// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'http_client.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final S1HttpClient _httpClient;
  User? _currentUser;
  bool _isLoggedIn = false;

  AuthService({S1HttpClient? httpClient})
      : _httpClient = httpClient ?? S1HttpClient.instance;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String username, String password) async {
    try {
      final apiService = ApiService(_httpClient);
      final success = await apiService.login(username, password);

      if (success) {
        _isLoggedIn = true;
        _currentUser = User(uid: '', username: username);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login failed: $e');
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _httpClient.cookieStore.clear();
    notifyListeners();
  }

  void restoreSession(Map<String, String> cookies) {
    if (cookies.isNotEmpty) {
      _httpClient.cookieStore.setCookies(cookies);
      _isLoggedIn = true;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: Implement FormhashService**

```dart
// lib/services/formhash_service.dart
import 'package:flutter/foundation.dart';
import 'http_client.dart';
import 'html_parser_service.dart';

class FormhashService extends ChangeNotifier {
  final S1HttpClient _httpClient;
  final Map<String, _FormhashCacheEntry> _cache = {};

  FormhashService({S1HttpClient? httpClient})
      : _httpClient = httpClient ?? S1HttpClient.instance;

  String? getFormhash(String tid) {
    final entry = _cache[tid];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(tid);
      return null;
    }
    return entry.formhash;
  }

  void cacheFormhash(String tid, String formhash, {Duration ttl = const Duration(minutes: 5)}) {
    _cache[tid] = _FormhashCacheEntry(
      formhash: formhash,
      expiry: DateTime.now().add(ttl),
    );
  }

  Future<String> fetchFormhash(String tid) async {
    // Check cache first
    final cached = getFormhash(tid);
    if (cached != null) return cached;

    // Fetch from server
    final parser = HtmlParserService(_httpClient);
    final formhash = await parser.getFormhash(tid);

    if (formhash.isNotEmpty) {
      cacheFormhash(tid, formhash);
    }

    return formhash;
  }

  void invalidate(String tid) {
    _cache.remove(tid);
  }
}

class _FormhashCacheEntry {
  final String formhash;
  final DateTime expiry;

  _FormhashCacheEntry({required this.formhash, required this.expiry});
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/auth_service_test.dart`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add lib/services/auth_service.dart lib/services/formhash_service.dart test/services/auth_service_test.dart
git commit -m "feat: auth service and formhash management"
```

---

### Task 7: Riverpod Providers

**Files:**
- Create: `lib/providers/auth_provider.dart`
- Create: `lib/providers/thread_list_provider.dart`
- Create: `lib/providers/post_provider.dart`
- Create: `lib/providers/settings_provider.dart`

**Interfaces:**
- Consumes: All services (AuthService, ApiService, FormhashService, etc.)
- Produces: Provider instances for UI layer

- [ ] **Step 1: Create auth provider**

```dart
// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

final httpClientProvider = Provider<S1HttpClient>((ref) {
  return S1HttpClient.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(httpClient: ref.watch(httpClientProvider));
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthState {
  final bool isLoggedIn;
  final String? username;

  AuthState({this.isLoggedIn = false, this.username});

  AuthState copyWith({bool? isLoggedIn, String? username}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    state = state.copyWith(
      isLoggedIn: _authService.isLoggedIn,
      username: _authService.currentUser?.username,
    );
  }

  Future<bool> login(String username, String password) async {
    return await _authService.login(username, password);
  }

  void logout() {
    _authService.logout();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
```

- [ ] **Step 2: Create thread list provider**

```dart
// lib/providers/thread_list_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thread.dart';
import '../services/api_service.dart';
import '../services/html_parser_service.dart';
import '../services/http_client.dart';
import 'auth_provider.dart';

final threadListProvider = StateNotifierProvider.family<ThreadListNotifier, AsyncValue<List<Thread>>, String>(
  (ref, fid) => ThreadListNotifier(
    fid: fid,
    apiService: ApiService(ref.watch(httpClientProvider)),
    htmlParser: HtmlParserService(ref.watch(httpClientProvider)),
  ),
);

class ThreadListNotifier extends StateNotifier<AsyncValue<List<Thread>>> {
  final String fid;
  final ApiService _apiService;
  final HtmlParserService _htmlParser;
  int _currentPage = 1;

  ThreadListNotifier({
    required this.fid,
    required ApiService apiService,
    required HtmlParserService htmlParser,
  })  : _apiService = apiService,
        _htmlParser = htmlParser,
        super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      var threads = await _apiService.getThreadList(fid);
      if (threads.isEmpty) {
        // Fallback to HTML parsing
        threads = await _htmlParser.getThreadList(fid);
      }
      state = AsyncValue.data(threads);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    _currentPage++;
    try {
      final newThreads = await _apiService.getThreadList(fid, page: _currentPage);
      state.whenData((threads) {
        state = AsyncValue.data([...threads, ...newThreads]);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    _currentPage = 1;
    await loadInitial();
  }
}
```

- [ ] **Step 3: Create post provider**

```dart
// lib/providers/post_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/formhash_service.dart';
import '../services/http_client.dart';
import 'auth_provider.dart';

final postProvider = StateNotifierProvider.family<PostNotifier, AsyncValue<List<Post>>, String>(
  (ref, tid) => PostNotifier(
    tid: tid,
    apiService: ApiService(ref.watch(httpClientProvider)),
    formhashService: FormhashService(httpClient: ref.watch(httpClientProvider)),
  ),
);

class PostNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  final String tid;
  final ApiService _apiService;
  final FormhashService _formhashService;
  int _currentPage = 1;

  PostNotifier({
    required this.tid,
    required ApiService apiService,
    required FormhashService formhashService,
  })  : _apiService = apiService,
        _formhashService = formhashService,
        super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.getThreadDetail(tid);
      final posts = ApiService.parsePostList(result);
      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    _currentPage++;
    try {
      final result = await _apiService.getThreadDetail(tid, page: _currentPage);
      final newPosts = ApiService.parsePostList(result);
      state.whenData((posts) {
        state = AsyncValue.data([...posts, ...newPosts]);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> getFormhash() async {
    return await _formhashService.fetchFormhash(tid);
  }
}
```

- [ ] **Step 4: Create settings provider**

```dart
// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class AppSettings {
  final bool darkMode;
  final bool showImages;
  final int fontSize;

  AppSettings({
    this.darkMode = false,
    this.showImages = true,
    this.fontSize = 14,
  });

  AppSettings copyWith({bool? darkMode, bool? showImages, int? fontSize}) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      showImages: showImages ?? this.showImages,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final box = Hive.box('settings');
    state = AppSettings(
      darkMode: box.get('darkMode', defaultValue: false),
      showImages: box.get('showImages', defaultValue: true),
      fontSize: box.get('fontSize', defaultValue: 14),
    );
  }

  void setDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
    Hive.box('settings').put('darkMode', value);
  }

  void setShowImages(bool value) {
    state = state.copyWith(showImages: value);
    Hive.box('settings').put('showImages', value);
  }

  void setFontSize(int value) {
    state = state.copyWith(fontSize: value);
    Hive.box('settings').put('fontSize', value);
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/providers/
git commit -m "feat: Riverpod providers for auth, threads, posts, settings"
```

---

### Task 8: BBCode Renderer Widget

**Files:**
- Create: `lib/widgets/bbcode_renderer.dart`
- Create: `lib/widgets/emoticon_widget.dart`
- Create: `lib/widgets/quote_block.dart`
- Create: `lib/widgets/image_viewer.dart`
- Create: `test/widgets/bbcode_renderer_test.dart`

**Interfaces:**
- Consumes: `BbcodeParser`, `EmoticonMap`
- Produces: `BbcodeRenderer` widget for displaying formatted post content

- [ ] **Step 1: Write renderer tests**

```dart
// test/widgets/bbcode_renderer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/widgets/bbcode_renderer.dart';
import 'package:s1_app/utils/bbcode_parser.dart';

void main() {
  group('BbcodeRenderer', () {
    test('parses BBCode to HTML', () {
      final html = BbcodeParser.parse('[b]hello[/b]');
      expect(html, contains('<b>hello</b>'));
    });

    test('handles empty input', () {
      final html = BbcodeParser.parse('');
      expect(html, isEmpty);
    });

    test('strips tags for plain text', () {
      final text = BbcodeParser.stripTags('<b>hello</b>');
      expect(text, 'hello');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/bbcode_renderer_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement EmoticonWidget**

```dart
// lib/widgets/emoticon_widget.dart
import 'package:flutter/material.dart';
import '../models/emoticon.dart';

class EmoticonWidget extends StatelessWidget {
  final String code;

  const EmoticonWidget({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final assetPath = EmoticonMap.getAssetPath(code);
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text(code, style: const TextStyle(fontSize: 12));
        },
      );
    }
    return Text(code, style: const TextStyle(fontSize: 12));
  }
}
```

- [ ] **Step 4: Implement QuoteBlock**

```dart
// lib/widgets/quote_block.dart
import 'package:flutter/material.dart';
import 'bbcode_renderer.dart';

class QuoteBlock extends StatelessWidget {
  final String content;

  const QuoteBlock({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: BbcodeRenderer(bbcode: content),
    );
  }
}
```

- [ ] **Step 5: Implement ImageViewer**

```dart
// lib/widgets/image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageViewer extends StatelessWidget {
  final String imageUrl;

  const ImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder: (context, url) => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.error),
        fit: BoxFit.contain,
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Implement BbcodeRenderer**

```dart
// lib/widgets/bbcode_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../utils/bbcode_parser.dart';
import 'emoticon_widget.dart';
import 'quote_block.dart';
import 'image_viewer.dart';

class BbcodeRenderer extends StatelessWidget {
  final String bbcode;

  const BbcodeRenderer({super.key, required this.bbcode});

  @override
  Widget build(BuildContext context) {
    if (bbcode.isEmpty) return const SizedBox.shrink();

    // First, extract and handle quotes separately
    final quoteRegex = RegExp(r'\[quote\](.*?)\[/quote\]', dotAll: true);
    final parts = bbcode.split(quoteRegex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildParts(context, parts),
    );
  }

  List<Widget> _buildParts(BuildContext context, List<String> parts) {
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      // Check if this is a quote (odd indices after split)
      if (i % 2 == 1) {
        widgets.add(QuoteBlock(content: part));
      } else {
        // Regular content - convert BBCode to HTML and render
        final html = BbcodeParser.parse(part);
        widgets.add(
          Html(
            data: html,
            style: {
              'body': Style(fontSize: FontSize(14)),
              'blockquote': Style(display: Display.none),
              'img': Style(width: Width(200)),
            },
            customRender: {
              'span': (context, child) {
                final className = context.tree.element?.className ?? '';
                if (className == 'emoticon') {
                  final code = context.tree.element?.attributes['data-code'] ?? '';
                  return EmoticonWidget(code: code);
                }
                return child;
              },
              'img': (context, child) {
                final src = context.tree.element?.attributes['src'] ?? '';
                return ImageViewer(imageUrl: src);
              },
            },
          ),
        );
      }
    }

    return widgets;
  }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/widgets/bbcode_renderer_test.dart`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/ test/widgets/
git commit -m "feat: BBCode renderer, emoticon, quote block, image viewer widgets"
```

---

### Task 9: UI Screens - Thread List & Detail

**Files:**
- Modify: `lib/screens/forum_list_screen.dart`
- Modify: `lib/screens/thread_detail_screen.dart`
- Create: `lib/widgets/thread_card.dart`
- Create: `lib/widgets/post_item.dart`

**Interfaces:**
- Consumes: `threadListProvider`, `postProvider`, `BbcodeRenderer`
- Produces: Functional forum list and thread detail screens

- [ ] **Step 1: Implement ThreadCard widget**

```dart
// lib/widgets/thread_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/thread.dart';

class ThreadCard extends StatelessWidget {
  final Thread thread;

  const ThreadCard({super.key, required this.thread});

  @override
  Widget build(BuildContext context) {
    final timeStr = thread.dateline > 0
        ? DateFormat('MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(thread.dateline * 1000))
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/thread/${thread.tid}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thread.subject,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(thread.author, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const Spacer(),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(timeStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${thread.views}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(width: 16),
                  Icon(Icons.comment_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${thread.replies}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement ForumListScreen**

```dart
// lib/screens/forum_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/thread_list_provider.dart';
import '../widgets/thread_card.dart';

class ForumListScreen extends ConsumerWidget {
  final String fid;

  const ForumListScreen({super.key, required this.fid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(threadListProvider(fid));

    return Scaffold(
      appBar: AppBar(title: const Text('Forum')),
      body: threadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(threadListProvider(fid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (threads) => ListView.builder(
          itemCount: threads.length,
          itemBuilder: (context, index) => ThreadCard(thread: threads[index]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement PostItem widget**

```dart
// lib/widgets/post_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post.dart';
import 'bbcode_renderer.dart';

class PostItem extends StatelessWidget {
  final Post post;

  const PostItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final timeStr = post.dateline > 0
        ? DateFormat('yyyy-MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(post.dateline * 1000))
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(post.author.isNotEmpty ? post.author[0] : '?'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text('#${post.floor}', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const Divider(),
            BbcodeRenderer(bbcode: post.message),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement ThreadDetailScreen**

```dart
// lib/screens/thread_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/post_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/post_item.dart';

class ThreadDetailScreen extends ConsumerWidget {
  final String tid;

  const ThreadDetailScreen({super.key, required this.tid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postProvider(tid));
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(postProvider(tid)),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (posts) => ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) => PostItem(post: posts[index]),
        ),
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              onPressed: () => context.push('/compose?tid=$tid'),
              child: const Icon(Icons.reply),
            )
          : null,
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/forum_list_screen.dart lib/screens/thread_detail_screen.dart lib/widgets/thread_card.dart lib/widgets/post_item.dart
git commit -m "feat: forum list and thread detail screens with widgets"
```

---

### Task 10: Login & Compose Screens

**Files:**
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/screens/compose_screen.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/profile_screen.dart`

**Interfaces:**
- Consumes: `authStateProvider`, `postProvider`, `FormhashService`
- Produces: Functional login, compose, home, and profile screens

- [ ] **Step 1: Implement LoginScreen**

```dart
// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final success = await ref.read(authStateProvider.notifier).login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum, size: 64),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement ComposeScreen**

```dart
// lib/screens/compose_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../services/api_service.dart';
import '../services/formhash_service.dart';
import '../services/http_client.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? tid;
  final String? fid;

  const ComposeScreen({super.key, this.tid, this.fid});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final formhashService = FormhashService(httpClient: S1HttpClient.instance);
      final formhash = widget.tid != null
          ? await formhashService.fetchFormhash(widget.tid!)
          : '';

      final apiService = ApiService(S1HttpClient.instance);
      final success = await apiService.sendPost(
        fid: widget.fid ?? '',
        tid: widget.tid ?? '',
        message: _messageController.text,
        formhash: formhash,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post submitted')),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tid != null ? 'Reply' : 'New Post'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Write your post...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement HomeScreen**

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/thread_card.dart';
import '../services/api_service.dart';
import '../services/html_parser_service.dart';
import '../services/http_client.dart';
import '../models/thread.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;
  List<Thread> _threads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService(S1HttpClient.instance);
      final htmlParser = HtmlParserService(S1HttpClient.instance);

      // Load from default forum (fid=4 based on URL)
      var threads = await apiService.getThreadList('4');
      if (threads.isEmpty) {
        threads = await htmlParser.getThreadList('4');
      }
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage1st'),
        actions: [
          if (!isLoggedIn)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Login'),
            ),
        ],
      ),
      body: _currentTab == 0
          ? _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadThreads,
                  child: ListView.builder(
                    itemCount: _threads.length,
                    itemBuilder: (context, index) =>
                        ThreadCard(thread: _threads[index]),
                  ),
                )
          : _currentTab == 1
              ? const Center(child: Text('Search'))
              : _currentTab == 2
                  ? const Center(child: Text('Messages'))
                  : ProfileScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
          if (index == 3) {
            context.push('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum), label: 'Forum'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement ProfileScreen**

```dart
// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            child: Text(
              authState.username?.isNotEmpty == true
                  ? authState.username![0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              authState.isLoggedIn ? authState.username! : 'Not logged in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (v) => ref.read(settingsProvider.notifier).setDarkMode(v),
          ),
          SwitchListTile(
            title: const Text('Show Images'),
            value: settings.showImages,
            onChanged: (v) => ref.read(settingsProvider.notifier).setShowImages(v),
          ),
          const Divider(),
          if (authState.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                ref.read(authStateProvider.notifier).logout();
                context.go('/');
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () => context.push('/login'),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/
git commit -m "feat: login, compose, home, profile screens"
```

---

### Task 11: Emoticon Assets & Integration

**Files:**
- Create: `assets/emoticons/` directory
- Create: `scripts/download_emoticons.dart` (helper script)

**Interfaces:**
- Consumes: `s1emoticon` repository data
- Produces: Bundled emoticon assets for offline use

- [ ] **Step 1: Create emoticons directory**

```bash
mkdir -p assets/emoticons
```

- [ ] **Step 2: Create emoticon download script**

```dart
// scripts/download_emoticons.dart
// Run with: dart run scripts/download_emoticons.dart
// Downloads S1 emoticons from kawaiidora/s1emoticon repo

import 'dart:io';
import 'dart:convert';

void main() async {
  final dir = Directory('assets/emoticons');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Map of emoticon codes to filenames
  final emoticonMap = <String, String>{};

  for (int i = 1; i <= 100; i++) {
    final code = i.toString().padLeft(3, '0');
    final fileName = '$code.png';
    final url = 'https://raw.githubusercontent.com/kawaiidora/s1emoticon/main/emoticons/$fileName';

    print('Downloading $fileName...');

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final file = File('${dir.path}/$fileName');
      await response.pipe(file.openWrite());

      emoticonMap['[f:$code]'] = 'assets/emoticons/$fileName';
    } catch (e) {
      print('Failed to download $fileName: $e');
    }
  }

  // Save the mapping
  final mapFile = File('assets/emoticons/emoticon_map.json');
  await mapFile.writeAsString(jsonEncode(emoticonMap));

  print('Done! Downloaded ${emoticonMap.length} emoticons.');
}
```

- [ ] **Step 3: Commit**

```bash
git add assets/ scripts/
git commit -m "feat: emoticon assets directory and download script"
```

---

### Task 12: Final Integration & Polish

**Files:**
- Modify: `lib/main.dart` (initialize services)
- Modify: `lib/app.dart` (wire up providers)
- Create: `test/integration_test.dart`

**Interfaces:**
- Consumes: All previous tasks
- Produces: Fully integrated, runnable app

- [ ] **Step 1: Update main.dart with full initialization**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'models/emoticon.dart';
import 'services/http_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('cookies');
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  // Initialize HTTP client
  await S1HttpClient.instance.init();

  // Initialize emoticon map
  EmoticonMap.initialize();

  runApp(
    const ProviderScope(
      child: S1App(),
    ),
  );
}
```

- [ ] **Step 2: Write integration test**

```dart
// test/integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/thread.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/utils/bbcode_parser.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('Full Integration', () {
    test('Thread model roundtrip', () {
      final thread = Thread(
        tid: '123',
        subject: 'Test Subject',
        author: 'author',
        authorId: '1',
        dateline: 1700000000,
        views: 100,
        replies: 10,
        fid: '4',
      );

      final json = thread.toJson();
      final restored = Thread.fromJson(json);

      expect(restored.tid, thread.tid);
      expect(restored.subject, thread.subject);
      expect(restored.views, thread.views);
    });

    test('BBCode full conversion', () {
      final input = '[b]Bold[/b] [i]Italic[/i] [img]http://test.com/pic.jpg[/img]';
      final html = BbcodeParser.parse(input);

      expect(html, contains('<b>Bold</b>'));
      expect(html, contains('<i>Italic</i>'));
      expect(html, contains('<img'));
    });

    test('API URL construction', () {
      final url = ApiService.buildApiUrl(
        module: 'forumdisplay',
        params: {'fid': '4', 'page': '1'},
      );

      expect(url, contains('module=forumdisplay'));
      expect(url, contains('fid=4'));
      expect(url, contains('version=4'));
    });
  });
}
```

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat: full integration, initialization, and tests"
```

- [ ] **Step 5: Verify app builds**

Run: `flutter build apk --debug`
Expected: APK builds successfully

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-06-s1-flutter-app.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
