---
phase: 07-data-layer
plan: 04
subsystem: data
tags: [dart, flutter, scanner, directory-listing, caching, mtime, concurrency, tdd, drift]

# Dependency graph
requires:
  - phase: 07-01
    provides: AppDatabase with getConfig/getProjectSettings, ProjectModel/GsdData/GitData data classes
  - phase: 07-02
    provides: parseGsdData() returning GsdParseResult with displayName, description, gsd, hasParseError
  - phase: 07-03
    provides: readAllGitData() reading git metadata for a list of project paths concurrently
provides:
  - ProjectScanner class with scanAll() method — top-level data assembly pipeline
  - ScanDirectoryNotFoundError exception with path and message fields
  - _FileCache class — mtime-based parse result caching per project path
  - scanAll(scanDirOverride?) returning List<ProjectModel> sorted by displayName
affects: [phase-08-watcher, phase-09-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Top-level orchestration service pattern: ProjectScanner ties together parser, git reader, and DB in scanAll()"
    - "mtime-based file cache: _FileCache keyed on path+microsecondsSinceEpoch skips re-parse when STATE.md unchanged"
    - "Concurrency with chunked DB lookups: per-project getProjectSettings() after batched git read"
    - "Stale detection two-path: git project uses lastCommitDate; non-git GSD project uses STATE.md mtime"
    - "Ignore pattern two-modes: exact match or wildcard-prefix (suffix *) applied after hidden-dir filter"

key-files:
  created:
    - pro_orc/lib/data/services/project_scanner.dart
    - pro_orc/test/data/project_scanner_test.dart
  modified: []

key-decisions:
  - "DB config row must exist before updateConfig() can write — tests call db.getConfig() first to trigger insert-on-first-access; silent no-op was the root cause of the failing wildcard-pattern test"
  - "scanDirOverride reads ignore patterns from DB even when path is overridden — enables full integration-style testing with in-memory DB"
  - "Hidden dirs (starting with .) removed from ignore list parsing (drop '.*' pattern) — hidden dir check is always separate and non-configurable"
  - "Dual-storage deferral confirmed: projectType reads from DB only in Phase 7; PROJECT.md type field does not exist yet in existing projects"

patterns-established:
  - "updateConfig-before-getConfig trap: always call getConfig() in tests before updateConfig() to ensure the id=1 row exists"
  - "Null semantics: isEmpty check on GsdData/GitData before assigning to ProjectModel fields — fields are null (not empty) for missing data"
  - "scanAll() is the single public entry point — all internal methods (_listProjectPaths, _parseGsdWithCache, _computeStale) are private"

requirements-completed:
  - SCAN-01
  - SCAN-02

# Metrics
duration: 3min
completed: 2026-02-19
---

# Phase 07 Plan 04: Project Scanner Summary

**ProjectScanner top-level data assembly service — scanAll() combining directory listing, GSD parsing, git reading, and DB type lookup with mtime-based _FileCache; 27 tests passing via TDD**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-19T20:51:18Z
- **Completed:** 2026-02-19T20:54:50Z
- **Tasks:** 3 (RED → GREEN → REFACTOR/verify)
- **Files modified:** 2 (both created)

## Accomplishments
- `ProjectScanner.scanAll()` scans a flat directory, filters hidden dirs and configurable ignore patterns, parses GSD data, reads git metadata, resolves project types from DB, and returns sorted `List<ProjectModel>`
- `ScanDirectoryNotFoundError` thrown for missing scan dir or unconfigured (empty) scan dir path
- `_FileCache` caches GSD parse results keyed on project path + STATE.md mtime — repeated `scanAll()` calls skip re-parsing unchanged projects
- 27 unit tests covering all specified cases: empty dir, files ignored, hidden dirs, ignore patterns (exact + wildcard), GSD/git/plain project assembly, DB type lookup, stale detection, cache invalidation

## Task Commits

TDD plan — three phases:

1. **RED: Write failing tests** - `8bb6017` (test)
2. **GREEN: Implement ProjectScanner** - `6e9bf32` (feat) — includes Rule 1 test fix

**Plan metadata:** (docs commit — see below)

_TDD tasks: test (RED) → feat (GREEN); no REFACTOR commit needed (no cleanup changes)_

## Files Created/Modified
- `pro_orc/lib/data/services/project_scanner.dart` - ProjectScanner class, ScanDirectoryNotFoundError, _FileCache, all private helpers
- `pro_orc/test/data/project_scanner_test.dart` - 27 tests covering full feature specification

## Decisions Made
- `db.getConfig()` must be called before `db.updateConfig()` in tests — the `insert-then-select` pattern in `getConfig()` creates the id=1 row on first access; `updateConfig()` uses a plain `update` that is a no-op if no row exists. This was the root cause of the failing wildcard-pattern test.
- `scanDirOverride` reads ignore patterns and gitBinaryPath from DB even when the scan path is overridden — this allows integration-style tests to control both path and config via in-memory DB
- Hidden dir filter (`name.startsWith('.')`) is always applied and is separate from the configurable ignore list — `.*` entries in `ignoreListJson` are dropped during parsing to avoid double-skipping

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test updateConfig() was no-op because DB row didn't exist yet**
- **Found during:** GREEN phase (running tests after implementation)
- **Issue:** `db.updateConfig(ignoreListJson: '["build*"]')` silently did nothing because the id=1 config row didn't exist yet. `getConfig()` creates it on first access via insert-then-select, but the test called `updateConfig` before ever calling `getConfig`. The wildcard pattern test got 2 results instead of 1.
- **Fix:** Added `await db.getConfig()` before `await db.updateConfig(...)` in the two ignore-pattern tests to ensure the config row exists
- **Files modified:** `pro_orc/test/data/project_scanner_test.dart`
- **Verification:** All 27 tests pass
- **Committed in:** `6e9bf32` (GREEN feat commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Minimal — test setup fix only. No behavior or scope change.

## Issues Encountered
- `widget_test.dart` fails due to pre-existing `MyApp` constructor issue from Phase 6. Not caused by Phase 7 changes. Confirmed by running `flutter test test/data/` separately: 59/59 pass.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 7 data layer complete: ProjectScanner is the top-level orchestration service tying all four plans together
- `scanAll(scanDirOverride: path)` ready for use in Phase 8 watcher service and Phase 9 UI providers
- All SCAN-01 and SCAN-02 requirements satisfied
- Phase 8 can consume `List<ProjectModel>` from a single `scanAll()` call; file watching triggers re-scan

---
*Phase: 07-data-layer*
*Completed: 2026-02-19*

## Self-Check: PASSED

All files verified present, commits 8bb6017 and 6e9bf32 confirmed in git log, scanner and test files contain expected content.
