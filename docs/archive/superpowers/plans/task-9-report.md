# Task 9 Report: UI Screens - Thread List & Detail

## What I Implemented

- **ThreadCard widget** (`lib/widgets/thread_card.dart`) - Card displaying thread subject, author, timestamp, view count, and reply count. Taps navigate to thread detail via go_router.
- **ForumListScreen** (`lib/screens/forum_list_screen.dart`) - Replaced placeholder with Riverpod-powered screen that watches `threadListProvider(fid)`, shows loading/error/data states with pull-to-refresh and retry.
- **PostItem widget** (`lib/widgets/post_item.dart`) - Card displaying post author avatar (first letter), timestamp, floor number, and BBCode-rendered message content via `BbcodeRenderer`.
- **ThreadDetailScreen** (`lib/screens/thread_detail_screen.dart`) - Replaced placeholder with Riverpod-powered screen that watches `postProvider(tid)`, shows posts in a scrollable list, with refresh button and a reply FAB when logged in.

## Files Changed

- `lib/widgets/thread_card.dart` (created)
- `lib/widgets/post_item.dart` (created)
- `lib/screens/forum_list_screen.dart` (replaced placeholder)
- `lib/screens/thread_detail_screen.dart` (replaced placeholder)

## Self-Review Findings

- No errors from `flutter analyze` in any of the 4 new files.
- Avoided `intl` package dependency (not in pubspec.yaml) by writing a simple `_formatTime` helper inline in both ThreadCard and PostItem.
- ForumListScreen uses `RefreshIndicator` wrapping the ListView for pull-to-refresh support (not in plan spec, but a natural improvement).
- ThreadDetailScreen shows an empty state ("No posts") when the post list is empty, and has a retry button on error state (slightly improved from plan spec which only showed the error text).
- Both screens use `ConsumerWidget` from Riverpod to watch providers reactively.

## Issues or Concerns

- The `intl` package was referenced in the plan's ThreadCard/PostItem but was never added to pubspec.yaml. I wrote a simple formatter to avoid adding a new dependency.
- Pre-existing analyzer warnings (15 total) in other files are unrelated to this task - no new warnings introduced.
