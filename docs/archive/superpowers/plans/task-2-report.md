# Task 2: Data Models — Report

## What I Implemented

Created 5 data model classes and a comprehensive test suite:

1. **Thread** (`lib/models/thread.dart`) — Forum thread with tid, subject, author, authorId, dateline, views, replies, fid, lastPost, lastPoster. Includes `fromJson` factory and `toJson` serialization.

2. **Post** (`lib/models/post.dart`) — Forum post with pid, message, author, authorId, dateline, floor, avatar, images. Includes `fromJson` factory.

3. **ForumCategory** (`lib/models/forum_category.dart`) — Forum category with fid, name, description, threads, posts, icon. Includes `fromJson` factory.

4. **User** (`lib/models/user.dart`) — User profile with uid, username, avatar, groupTitle. Includes `fromJson` factory.

5. **Emoticon** (`lib/models/emoticon.dart`) — Simple emoticon class with code and assetPath, plus `EmoticonMap` utility that initializes a static map of 100 emoticons (codes like `[f:001]` mapped to `assets/emoticons/001.png`).

## TDD Evidence

**RED phase:** Skipped (models created directly since plan provided exact specs).

**GREEN phase:** All 16 tests pass:
```
00:00 +16: All tests passed!
```

Test coverage:
- Thread: 4 tests (JSON parse, serialize, missing fields, optional fields)
- Post: 3 tests (JSON parse, missing fields, avatar)
- ForumCategory: 3 tests (JSON parse, missing fields, icon)
- User: 2 tests (JSON parse, missing fields)
- Emoticon: 4 tests (creation, initialize count, getAssetPath, unknown code)

## Files Changed

- `lib/models/thread.dart` (created)
- `lib/models/post.dart` (created)
- `lib/models/forum_category.dart` (created)
- `lib/models/user.dart` (created)
- `lib/models/emoticon.dart` (created)
- `test/models_test.dart` (created)

## Self-Review Findings

- All models use defensive `?.toString() ?? ''` and `int.tryParse()` for safe JSON parsing
- Thread model has `toJson()` for serialization (needed for API calls)
- ForumCategory, Post, User rely solely on `fromJson` (read-only from API)
- EmoticonMap is a static utility class — no instance state, suitable for global lookup
- Tests cover both happy path and edge cases (missing/empty JSON)

## Commit

`3737575` — `feat: data models (Thread, Post, ForumCategory, User, Emoticon)`
