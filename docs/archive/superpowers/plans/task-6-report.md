# Task 6: Auth Service & Formhash Management - Report

## What Was Implemented

### AuthService (`lib/services/auth_service.dart`)
- `ChangeNotifier`-based auth state management
- `login(username, password)` - delegates to `ApiService.login()`, updates state on success
- `logout()` - clears user state and cookies
- `restoreSession(cookies)` - restores login state from saved cookies
- `isLoggedIn` / `currentUser` getters for state inspection
- Optional `S1HttpClient?` parameter for testability (null-safe cookie operations)

### FormhashService (`lib/services/formhash_service.dart`)
- `ChangeNotifier`-based formhash cache management
- `cacheFormhash(tid, formhash, {ttl})` - stores formhash with configurable TTL (default 5 min)
- `getFormhash(tid)` - retrieves cached formhash, returns null if expired
- `fetchFormhash(tid)` - checks cache first, fetches from server via `HtmlParserService` if needed
- `invalidate(tid)` - removes cached entry for a thread
- Internal `_FormhashCacheEntry` class for expiry tracking

## TDD Evidence

### RED Phase
```
test/services/auth_service_test.dart:2:8: Error: Error when reading 'lib/services/auth_service.dart': 文件不存在。
test/services/auth_service_test.dart:3:8: Error: Error when reading 'lib/services/formhash_service.dart': 文件不存在。
```
Tests failed with import errors - services did not exist yet.

### GREEN Phase
```
00:00 +9: All tests passed!
```
All 9 new tests pass. Full suite: 79/79 tests passing.

## Files Changed
- `lib/services/auth_service.dart` (created)
- `lib/services/formhash_service.dart` (created)
- `test/services/auth_service_test.dart` (created)

## Self-Review Findings

1. **Testability**: Both services accept optional `S1HttpClient?` parameter. When null, network operations are skipped gracefully. This allows pure unit tests without Hive initialization.

2. **Expired cache test**: Initial test used `Duration.zero` which was flaky (same-microsecond evaluation). Fixed to `Duration(seconds: -1)` for deterministic expiry.

3. **No Hive dependency in tests**: Unlike other service tests, auth/formhash tests don't require Hive setup since they test pure state management and caching logic without network calls.

## Commit
- `ef543ae` feat: auth service and formhash management
