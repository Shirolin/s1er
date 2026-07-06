# Task 3: HTTP Client & Cookie Management — Report

## What I Implemented

### CookieStore (`lib/utils/cookie_store.dart`)
- Hive-backed cookie persistence for session management
- `setCookies()` — merges key-value pairs into the Hive box
- `getCookies()` — returns all stored cookies as a Map
- `toHeaderString()` — formats cookies as `key=value; key2=value2` for HTTP `Cookie` header
- `clear()` — async delete of all cookies (async because `Box.clear()` returns a Future)
- `isEmpty` — checks if the store has any cookies
- `init()` / `initSync()` — async and sync initialization (sync variant for tests where the box is pre-opened)

### S1HttpClient (`lib/services/http_client.dart`)
- Singleton Dio-based HTTP client configured with Stage1st mobile User-Agent
- **Rate limiting**: sliding window of request timestamps, enforces max 2 requests/second (from `S1Constants.maxRequestsPerSecond`)
- **Cookie injection**: interceptor reads `CookieStore` and adds `Cookie` header to every request
- **Cookie extraction**: interceptor parses `Set-Cookie` response headers and persists new cookies
- **Public API**: `get(url, {queryParameters})`, `post(url, {data})`, `cookieStore` getter
- `resetInstance()` for test teardown

### Tests (`test/services/http_client_test.dart`)
7 tests covering CookieStore:
1. saves and retrieves cookies
2. clears cookies
3. formats cookies for HTTP header
4. isEmpty reflects box state
5. overwrites existing cookie values
6. returns empty map when no cookies set
7. toHeaderString returns empty string when no cookies

## TDD Evidence

**RED phase** — Tests compiled and failed with:
```
Error when reading 'lib/utils/cookie_store.dart': 系统找不到指定的路径。
Method not found: 'CookieStore'.
```

**GREEN phase** — All 24 tests pass (16 models + 7 CookieStore + 1 widget smoke):
```
00:00 +24: All tests passed!
```

## Files Changed

| File | Action |
|------|--------|
| `lib/utils/cookie_store.dart` | Created |
| `lib/services/http_client.dart` | Created |
| `test/services/http_client_test.dart` | Created |

## Self-Review Findings

1. **`clear()` is async** — Hive's `Box.clear()` returns `Future<int>`. The original plan had `clear()` as sync (`void clear()`). Changed to `Future<void> clear() async` to properly await the deletion. This is a deviation from the plan but necessary for correctness.

2. **`initSync()` added** — The plan didn't include this, but tests need to bind to an already-open Hive box without calling `Hive.openBox()` again. Added `initSync()` which calls `Hive.box()` (sync getter) instead of `Hive.openBox()` (async). This avoids the race condition where `init()` opens a new box reference while the test's `setUp` holds a different one.

3. **Hive test setup** — Tests use `Directory.systemTemp.createTempSync()` for an isolated Hive directory, with `setUp` clearing the box between tests and `tearDownAll` closing Hive and deleting the temp directory. This prevents test pollution.

4. **S1HttpClient not unit-tested for network calls** — The plan only specified CookieStore tests. S1HttpClient's rate limiting, cookie injection, and extraction are integration-level behaviors that require mocking Dio or a real server. The singleton is tested indirectly through the CookieStore tests and will be validated in integration testing.

## Commit

```
c949796 feat: HTTP client with cookie management and rate limiting
```

3 files changed, 238 insertions(+).
