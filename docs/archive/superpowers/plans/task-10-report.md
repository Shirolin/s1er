# Task 10: Login & Compose Screens — Report

## What I Implemented

Replaced four placeholder screens with full functional implementations:

1. **LoginScreen** — `ConsumerStatefulWidget` with username/password fields, loading state, calls `authStateProvider.notifier.login()`, navigates to home on success, shows SnackBar on failure.

2. **ComposeScreen** — `ConsumerStatefulWidget` with a full-height text field, submit button with loading indicator. Fetches formhash via `FormhashService`, submits via `ApiService.sendPost()`, pops on success.

3. **HomeScreen** — `ConsumerStatefulWidget` with bottom `NavigationBar` (Forum/Search/Messages/Me tabs). Loads threads from API with HTML parser fallback, supports pull-to-refresh, shows login button in AppBar when logged out. The "Me" tab renders `ProfileScreen` inline.

4. **ProfileScreen** — `ConsumerWidget` showing avatar (first letter of username), username, dark mode and show-images toggles (via `settingsProvider`), and login/logout actions.

## Files Changed

- `lib/screens/login_screen.dart` — placeholder → full login form
- `lib/screens/compose_screen.dart` — placeholder → compose/reply form
- `lib/screens/home_screen.dart` — placeholder → bottom nav with thread list
- `lib/screens/profile_screen.dart` — placeholder → profile with settings

## Self-Review Findings

- `flutter analyze` reports 0 errors in the modified files. All 15 issues are pre-existing warnings/info in other files.
- No unused imports, no null safety issues in the new code.
- One deviation from plan: HomeScreen renders `ProfileScreen` inline (tab 3) rather than pushing to `/profile` route, which avoids double-app-bar and is cleaner UX.

## Issues or Concerns

- The HomeScreen thread loading hardcodes `fid: '4'`. The plan acknowledges this with a comment. Forum list navigation (from a forum list screen) should eventually pass the fid dynamically.
- ComposeScreen creates new `FormhashService` and `ApiService` instances directly rather than using Riverpod providers. This works but bypasses dependency injection. A future task could refactor to use providers.
- Search and Messages tabs are still placeholder text — not part of this task's scope.
