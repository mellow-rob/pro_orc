---
phase: 08-watcher
plan: 02
subsystem: ui
tags: [dart, flutter, flutter_riverpod, riverpod, provider, stream_provider, future_provider, consumer_stateful_widget]

requires:
  - phase: 08-watcher-01
    provides: WatcherService with StreamController.broadcast() re-broadcast pattern and 350ms debounce
  - phase: 07-data-layer
    provides: AppDatabase, ProjectScanner, ProjectModel infrastructure

provides:
  - ProviderScope wrapping runApp in main.dart — all Riverpod providers accessible throughout widget tree
  - appDatabaseProvider (keepAlive Provider<AppDatabase>) — singleton database lifetime
  - projectScannerProvider (Provider<ProjectScanner>) — scanner using singleton DB
  - watcherProvider (keepAlive StreamProvider<WatchEvent>) — never-disposed file watcher stream
  - projectsProvider (FutureProvider<List<ProjectModel>>) — live project list with watcher-driven invalidation
  - ShellScreen as ConsumerStatefulWidget — watches projectsProvider, shows live project count

affects:
  - 08-03 and beyond (animations, project list UI, project cards)
  - phase 09 (UI/design system builds on this live data layer)

tech-stack:
  added: []
  patterns:
    - "Riverpod manual (non-codegen) provider pattern: Provider, StreamProvider, FutureProvider with unified Ref"
    - "keepAlive on watcherProvider: locked decision — watcher never disposes so filesystem monitoring is always active"
    - "ref.listen(watcherProvider) in FutureProvider body: watcher event → invalidateSelf() → rescan → UI rebuild"
    - "ConsumerStatefulWidget + ConsumerState: use when StatefulWidget lifecycle (mixins) and Riverpod ref both needed"

key-files:
  created:
    - pro_orc/lib/providers/database_provider.dart
    - pro_orc/lib/providers/watcher_provider.dart
    - pro_orc/lib/providers/projects_provider.dart
  modified:
    - pro_orc/lib/main.dart
    - pro_orc/lib/features/shell/shell_screen.dart

key-decisions:
  - "ConsumerStatefulWidget (not ConsumerWidget) for ShellScreen — required because WindowListener and TrayListener mixins need StatefulWidget lifecycle; ref is available directly on ConsumerState"
  - "ref.listen in FutureProvider body (not ref.watch) — listen does not create a dependency, only sets up a side-effect callback; invalidateSelf() triggers full rescan on each debounced watcher event"
  - "withOpacity replaced with withValues(alpha:) in shell_screen.dart — fixed deprecation warnings introduced while updating the file; pre-existing warnings in glow_border_shell.dart and launch_dialog.dart deferred"

patterns-established:
  - "Riverpod watcher-to-UI chain: WatcherService → watcherProvider (StreamProvider/keepAlive) → projectsProvider (FutureProvider/ref.listen/invalidateSelf) → ConsumerWidget(ref.watch) → UI rebuild"
  - "keepAlive on infrastructure providers: use for services that must persist for the entire app lifetime (DB, watcher)"

requirements-completed:
  - LIVE-02
  - LIVE-03

duration: 3min
completed: 2026-02-19
---

# Phase 08 Plan 02: Riverpod Provider Chain Summary

**Full Riverpod provider chain: ProviderScope → appDatabaseProvider → watcherProvider (keepAlive StreamProvider) → projectsProvider (FutureProvider with ref.listen invalidation) → ConsumerStatefulWidget ShellScreen showing live project count**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-19T21:53:03Z
- **Completed:** 2026-02-19T21:56:01Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Created three provider files (database_provider.dart, watcher_provider.dart, projects_provider.dart) wiring the full reactive chain
- Wrapped runApp with ProviderScope in main.dart — Riverpod now available throughout the widget tree
- Converted ShellScreen from StatefulWidget to ConsumerStatefulWidget — shows live "N projects discovered" text from projectsProvider; handles loading (spinner) and error (red text) states

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Riverpod providers and wire ProviderScope** - `ae171dc` (feat)
2. **Task 2: Convert ShellScreen to ConsumerStatefulWidget with live project data** - `7da5240` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `pro_orc/lib/providers/database_provider.dart` — appDatabaseProvider (keepAlive singleton) and projectScannerProvider
- `pro_orc/lib/providers/watcher_provider.dart` — StreamProvider<WatchEvent> with keepAlive, reads scanDir from DB config
- `pro_orc/lib/providers/projects_provider.dart` — FutureProvider<List<ProjectModel>> with ref.listen(watcherProvider) → invalidateSelf()
- `pro_orc/lib/main.dart` — Added ProviderScope wrapper and flutter_riverpod import
- `pro_orc/lib/features/shell/shell_screen.dart` — ConsumerStatefulWidget with ref.watch(projectsProvider), loading/error/data states

## Decisions Made

- **ConsumerStatefulWidget for ShellScreen:** ShellScreen uses `WindowListener` and `TrayListener` mixins which require `StatefulWidget` lifecycle. `ConsumerStatefulWidget` + `ConsumerState` is the correct Riverpod pattern when you need both mixin lifecycle and `ref` access. `ref` is available directly on `ConsumerState` without wrapping in a `Consumer` widget.
- **ref.listen in FutureProvider body:** Using `ref.listen` (not `ref.watch`) in `projectsProvider` — `listen` registers a callback side-effect without creating a rebuild dependency on `watcherProvider`. When a debounced `WatchEvent` arrives with `hasValue`, `invalidateSelf()` triggers a fresh `scanAll()`. This is the correct pattern for watcher-driven FutureProvider invalidation in Riverpod 3.x.
- **withOpacity → withValues(alpha:):** Fixed two `withOpacity` deprecation warnings in shell_screen.dart introduced while rewriting the file. Four pre-existing instances in `glow_border_shell.dart` and `launch_dialog.dart` are out of scope (files not modified in this plan) and logged to deferred-items.md.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed withOpacity deprecation in shell_screen.dart**
- **Found during:** Task 2 (dart analyze verification)
- **Issue:** The plan's build() example used `Colors.white.withOpacity()` which is deprecated in Flutter 3.41+; dart analyze reported 2 `info` issues in the newly written file
- **Fix:** Replaced both `Colors.white.withOpacity(x)` calls with `Colors.white.withValues(alpha: x)` in shell_screen.dart
- **Files modified:** `pro_orc/lib/features/shell/shell_screen.dart`
- **Verification:** `dart analyze lib/features/shell/shell_screen.dart` → No issues found
- **Committed in:** `7da5240` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — deprecated API replaced with current equivalent)
**Impact on plan:** Trivial fix. No behavior change. Dart analyze passes clean on all new/modified files.

## Issues Encountered

None — both tasks executed cleanly on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Full reactive chain is complete: file edit → WatcherService → watcherProvider → projectsProvider invalidation → ShellScreen rebuild
- The "N projects discovered" text demonstrates the chain is wired end-to-end
- Phase 08-03 (if planned) can add project list UI, project cards, or animation on top of this live data layer
- Phase 09 (design system) has a working reactive data foundation to build on
- Note: Pre-existing `withOpacity` deprecations in `glow_border_shell.dart` and `launch_dialog.dart` are logged in `deferred-items.md` — not blockers

---
*Phase: 08-watcher*
*Completed: 2026-02-19*

## Self-Check: PASSED

- FOUND: `pro_orc/lib/providers/database_provider.dart`
- FOUND: `pro_orc/lib/providers/watcher_provider.dart`
- FOUND: `pro_orc/lib/providers/projects_provider.dart`
- FOUND: `.planning/milestones/v1.1-phases/08-watcher/08-02-SUMMARY.md`
- FOUND: commit `ae171dc` (Task 1)
- FOUND: commit `7da5240` (Task 2)
