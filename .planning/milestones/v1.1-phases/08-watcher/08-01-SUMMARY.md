---
phase: 08-watcher
plan: 01
subsystem: data
tags: [dart, watcher, stream_transform, flutter_riverpod, directoryWatcher, debounce, filesystem]

requires:
  - phase: 07-data-layer
    provides: ProjectScanner, AppDatabase, and project model infrastructure this watcher service feeds into

provides:
  - WatcherService class wrapping DirectoryWatcher with 350ms trailing-edge debounce
  - flutter_riverpod 3.2.1 dependency (first Riverpod in project)
  - watcher 1.2.1 and stream_transform 2.1.1 as direct dependencies
  - 4 integration tests covering create, modify, debounce, and watcher#79 defense

affects:
  - 08-02 (watcherProvider — Riverpod StreamProvider wrapping WatcherService)
  - 08-03 and beyond (projectsProvider, UI update animation)

tech-stack:
  added:
    - flutter_riverpod 3.2.1
    - watcher 1.2.1 (was transitive, now direct)
    - stream_transform 2.1.1 (was transitive, now direct)
  patterns:
    - StreamController.broadcast() re-broadcast pattern for DirectoryWatcher — keeps internal subscription alive so watcher event loop runs and ready future completes
    - Permanent internal subscription in service constructor — ensures watcher is always listening regardless of external subscriber count
    - Subscribe before awaiting ready in tests — Dart broadcast stream pattern requirement

key-files:
  created:
    - pro_orc/lib/data/services/watcher_service.dart
    - pro_orc/test/data/services/watcher_service_test.dart
  modified:
    - pro_orc/pubspec.yaml
    - pro_orc/pubspec.lock

key-decisions:
  - "WatcherService uses StreamController.broadcast() with permanent internal subscription — DirectoryWatcher requires active listener to drive event loop; ready future hangs without it"
  - "Watcher created eagerly in constructor (not lazily) — internal subscription must exist before any caller awaits ready"
  - "350ms trailing-edge debounce applied on broadcast stream from StreamController, not directly on DirectoryWatcher.events — allows multiple independent debounced subscriptions"
  - "dispose() cancels internal subscription and closes StreamController — clean lifecycle contract"

patterns-established:
  - "WatcherService pattern: wrap DirectoryWatcher in StreamController.broadcast() with permanent internal sub — reusable for any always-on file watcher service"
  - "Integration test pattern: subscribe to events BEFORE awaiting service.ready — required by Dart single-subscription stream semantics under broadcast wrapper"

requirements-completed:
  - LIVE-01

duration: 7min
completed: 2026-02-19
---

# Phase 08 Plan 01: WatcherService Summary

**DirectoryWatcher wrapped in StreamController.broadcast() with 350ms trailing-edge debounce, defensive watcher#79 error handling, and 4 passing integration tests**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-19T21:43:12Z
- **Completed:** 2026-02-19T21:50:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added flutter_riverpod 3.2.1 (first Riverpod in project), watcher 1.2.1, and stream_transform 2.1.1 to pubspec.yaml
- Created WatcherService with permanent internal subscription, 350ms trailing-edge debounce, and defensive error handling against watcher#79
- All 4 integration tests pass: file create, file modify, debounce collapse (LIVE-01), and watcher#79 defense

## Task Commits

Each task was committed atomically:

1. **Task 1: Add dependencies and create WatcherService** - `feb2d79` (feat)
2. **Task 2: Integration tests for WatcherService** - `6386aa7` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `pro_orc/pubspec.yaml` - Added flutter_riverpod ^3.2.1, watcher ^1.2.1, stream_transform ^2.1.1
- `pro_orc/pubspec.lock` - Resolved new dependencies
- `pro_orc/lib/data/services/watcher_service.dart` - WatcherService with broadcast re-broadcast pattern and 350ms debounce
- `pro_orc/test/data/services/watcher_service_test.dart` - 4 integration tests using real temp directories

## Decisions Made

- **StreamController.broadcast() re-broadcast pattern:** `DirectoryWatcher` requires an active listener to drive its internal event loop — `ready` future hangs without one. Wrapping in a `StreamController.broadcast()` with a permanent internal subscription solves this. Multiple callers can subscribe independently to `events` without each needing to manage the watcher lifecycle.
- **Eager construction:** Watcher and internal subscription created in constructor (not lazily) so `ready` can be safely awaited by callers without first accessing `events`.
- **Debounce on broadcast stream:** `.debounce(350ms)` applied on `_controller.stream` (the broadcast) rather than directly on `_watcher.events`, so each `service.events` call gets an independent debounced subscription.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Refactored WatcherService to use StreamController.broadcast() with permanent internal subscription**
- **Found during:** Task 2 (integration test execution)
- **Issue:** Original implementation used lazy `DirectoryWatcher` creation. `DirectoryWatcher.ready` future hangs without an active listener on `.events` — the watcher's internal event loop requires a consuming subscriber to make progress. Tests 2, 3, and 4 all timed out at 30s because `service.ready` (which called `await _watcher!.ready` without a listener) would never complete after the first test.
- **Fix:** Refactored WatcherService to create `DirectoryWatcher` and a permanent `StreamController.broadcast()` in the constructor. The internal subscription forwards events through the controller, keeping the event loop alive. `events` getter now returns `_controller.stream.debounce(...)`. `dispose()` cancels the internal sub and closes the controller.
- **Files modified:** `pro_orc/lib/data/services/watcher_service.dart`
- **Verification:** All 4 integration tests pass (was 1/4 before fix, 4/4 after)
- **Committed in:** `6386aa7` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in WatcherService stream lifecycle)
**Impact on plan:** Required fix — without it 3 of 4 tests hung and ready future was unusable. No scope creep. Implementation is cleaner and more robust with the broadcast re-broadcast pattern.

## Issues Encountered

- `DirectoryWatcher.ready` silently hangs without an active stream listener — not documented in the package API. Discovered by debugging test timeouts. The fix (permanent internal subscription) is the correct pattern for always-on watcher services.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- WatcherService is fully testable and ready to be wrapped in a Riverpod `StreamProvider` (Phase 08-02)
- `flutter_riverpod 3.2.1` is installed — `ProviderScope` can be added to `main.dart` in 08-02
- The broadcast re-broadcast pattern means `watcherProvider` can subscribe to `WatcherService.events` normally without worrying about stream lifecycle
- No blockers

---
*Phase: 08-watcher*
*Completed: 2026-02-19*
