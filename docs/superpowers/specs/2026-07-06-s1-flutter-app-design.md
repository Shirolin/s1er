# S1 Forum Flutter App - Design Spec

## Overview

A third-party Flutter client for Stage1st (S1) forum, based on Discuz! X3.5. Provides full CRUD functionality: browsing forums, reading threads, posting/replying, liking, and bookmarking.

## Goals

- Cross-platform mobile app (iOS + Android) from single Flutter codebase
- Full CRUD: browse, login, post, reply, like, bookmark
- Fast, smooth scrolling with offline emoticon support
- Resilient data fetching: API-first with HTML fallback

## Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Framework | Flutter 3.x | Cross-platform, strong community |
| State | Riverpod | Type-safe, testable, composable |
| Network | Dio | Interceptors for auth/retry/rate-limit |
| Storage | Hive | Fast NoSQL for caching |
| Router | go_router | Declarative, deep-link support |
| Images | cached_network_image | Disk cache + placeholders |
| Theme | Material 3 | System dark mode, custom S1 palette |

## Architecture

```
┌─────────────────────────────────────────────┐
│                  UI Layer                    │
│  Screens → Widgets → BBCode Renderer        │
├─────────────────────────────────────────────┤
│              State Layer (Riverpod)          │
│  AuthProvider, ThreadProvider, PostProvider  │
├─────────────────────────────────────────────┤
│              Service Layer                   │
│  ApiService, HtmlParserService, AuthService  │
├─────────────────────────────────────────────┤
│              Network Layer                   │
│  Dio HTTP Client (Cookie, UA, Rate-limit)   │
└─────────────────────────────────────────────┘
```

## Project Structure

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

## Data Layer

### Data Source Strategy

**Primary: Discuz Mobile API**
- Endpoint: `api/mobile/index.php?version=4&module=<module>&<params>`
- Modules: `forumdisplay` (thread list), `viewthread` (thread detail), `forumindex` (forum list), `login`, `sendpm`, etc.
- Returns JSON, directly mapped to Dart models

**Fallback: HTML Parsing**
- When API returns errors or missing data, fall back to `forum.php?mobile=2`
- Parse DOM with `html` package
- Extract key fields via CSS selectors/XPath

### HTTP Client

```dart
class S1HttpClient {
  // - Mobile browser User-Agent
  // - Cookie persistence (Hive)
  // - Request rate limiter (max N req/sec)
  // - Auto-retry on 5xx
  // - 403/captcha detection → notify auth provider
}
```

### Cookie Management

- Store cookies in Hive box after login
- Inject into every request via Dio interceptor
- Detect expiry via HTTP 401/403 responses
- Force re-login on persistent auth failure

### Formhash Management

- Fetch fresh formhash when entering thread detail or compose screen
- Cache per-thread with TTL (e.g., 5 minutes)
- Attach to POST requests (reply, like, bookmark)

## Content Rendering

### BBCode Parser

Converts BBCode/HTML string to an intermediate representation, then to Flutter widgets.

**Supported tags:**
- Text formatting: `[b]`, `[i]`, `[u]`, `[s]`, `[color]`, `[size]`
- Images: `[img]` → CachedNetworkImage
- Links: `[url]` → GestureDetector + url_launcher
- Quotes: `[quote]` → nested QuoteBlock widget
- Emoticons: `[f:xxx]` → local Asset image
- Lists: `[list]`, `[*]` → Column + widgets
- Tables: `[table]` → Table widget
- Code: `[code]` → monospace styled container

### Emoticon System

- Bundle S1 emoticon pack in `assets/emoticons/`
- Map file: `[f:001]` → `assets/emoticons/001.png`
- Regex replace during BBCode parsing
- Zero network requests, smooth scrolling

## Authentication

### Login Flow

1. User enters credentials on login screen
2. POST to `member.php?mod=logging&action=login` with form data
3. Extract Set-Cookie headers from response
4. Persist cookies to Hive
5. Update auth state via Riverpod

### Session Maintenance

- Every request carries persisted cookies
- On 401/403: check if cookie expired
- If expired: clear auth state, navigate to login
- Provide "auto-login" option: re-submit saved credentials

## Navigation

### Bottom Tab Bar

```
┌─────────────────────────────────────┐
│  Forum  │  Search  │  Message │ Me  │
├─────────────────────────────────────┤
│         Page Content                │
└─────────────────────────────────────┘
```

- **Forum**: Category list → Thread list → Thread detail (3-level push)
- **Search**: Full-text search across forums
- **Message**: Notifications, private messages
- **Me**: Profile, settings, bookmarks, history

### Routing (go_router)

```dart
GoRouter routes = GoRouter(
  routes: [
    GoRoute(path: '/', builder: HomeScreen),
    GoRoute(path: '/forum/:fid', builder: ForumListScreen),
    GoRoute(path: '/thread/:tid', builder: ThreadDetailScreen),
    GoRoute(path: '/login', builder: LoginScreen),
    GoRoute(path: '/compose', builder: ComposeScreen),
    GoRoute(path: '/profile', builder: ProfileScreen),
  ],
);
```

## Key Screens

### Thread Detail Screen (Core Page)

The most complex screen. Displays:
- Thread title, author, timestamp
- Original post (OP) with full BBCode rendering
- Paginated replies
- Like/reply/bookmark actions
- Formhash-aware reply submission

### Compose Screen

- Rich text input with toolbar (bold, italic, image, emoticon picker)
- Attach images via device gallery/camera
- Preview mode before submit
- Auto-attach formhash

## Error Handling

- Network errors: Show snackbar with retry option
- Auth errors: Redirect to login
- Content parse errors: Show raw text fallback
- Rate limiting: Backoff timer + user notification

## Testing Strategy

- Unit tests: BBCode parser, API response parsing
- Widget tests: Thread card, post item, quote block
- Integration tests: Login flow, navigation, compose flow

## Open Questions

- S1 API endpoint availability needs verification during implementation
- Emoticon pack size may be large; consider lazy loading or subset
- Push notifications scope TBD (FCM/APNs integration)

## References

- S1-Next (Android): github.com/ykrank/S1-Next
- Stage1st-Reader (iOS): github.com/ainopara/Stage1st-Reader
- S1 Emoticons: github.com/kawaiidora/s1emoticon
