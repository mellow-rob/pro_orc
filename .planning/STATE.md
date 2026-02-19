# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-19)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 8 — Reactive State / Watcher Service (v1.1)

## Current Position

Phase: 8 of 11 (Watcher Service) — IN PROGRESS
Plan: 1 of 3 complete (08-01 complete — WatcherService with 350ms debounce and integration tests)
Status: Phase 8 in progress — 08-02 (watcherProvider Riverpod StreamProvider) next
Last activity: 2026-02-19 — Phase 8, Plan 01 complete (WatcherService created)

Progress: [########░░░░░░░░░░░░] ~40% (v1.1, 8/~20 plans complete)

## Performance Metrics

**Velocity (v1.0 reference):**
- Total plans completed: 12
- Average duration: ~2 min/plan
- Total execution time: ~0.35 hours

**v1.1 Velocity:**
- Plans completed: 3
- Average duration: ~12 min/plan

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 06    | 01   | 14 min   | 2     | 40    |
| 06    | 02   | 7 min    | 2     | 6     |
| 06    | 03   | ~15 min  | 2     | 0     |
| 07    | 01   | 2 min    | 2     | 9     |
| 07    | 02   | 3 min    | 3     | 2     |
| 07    | 03   | 6 min    | 3     | 4     |
| 07    | 04   | 3 min    | 3     | 2     |
| 08    | 01   | 7 min    | 2     | 4     |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full decision log in PROJECT.md Key Decisions table.
v1.0 decisions archived to milestones/v1.0-ROADMAP.md.

**v1.1 key architectural decisions (pre-build):**
- Phase 6: Sandbox must be disabled in BOTH entitlement files and verified in `flutter build macos`, not just `flutter run`
- Phase 6: AppDelegate.swift must return false from `applicationShouldTerminateAfterLastWindowClosed` or closing window quits app
- Phase 7: Use `runInShell: true` on all `Process.run` calls — GUI app PATH does not include Homebrew git
- Phase 8: `watcherProvider` uses `ref.keepAlive()` — never disposed; `projectsProvider` invalidates on watcher events
- 08-01: WatcherService uses StreamController.broadcast() with permanent internal subscription — DirectoryWatcher.ready hangs without active listener; eager construction ensures ready is safely awaitable
- 08-01: Debounce applied on StreamController broadcast stream, not directly on DirectoryWatcher.events — allows independent debounced subscriptions per caller
- Phase 9: All OKLCH design tokens must be pre-converted to sRGB hex before Phase 9 begins (use oklch.com)

**v1.1 decisions made during execution:**
- 07-02: GsdParseResult is a local class in gsd_parser.dart (not a shared model) — belongs to parser's contract, not the data model layer
- 07-02: Test assertions use result.gsd.isEmpty (semantic) over equals(GsdData.empty) — GsdData lacks == override, semantic check is more appropriate
- 07-03: Real temp git repos used in TDD tests (no mocking) — createTempGitRepo() helper creates actual git init + commit in systemTemp
- 07-03: meta package added as explicit dependency (was transitive-only) — dart analyze requires direct dep for imported packages
- 07-04: updateConfig() is a no-op if db row absent — call getConfig() first in tests to trigger insert-on-first-access before writing config
- 07-04: ProjectScanner reads ignore patterns from DB even when scanDirOverride is provided — full config integration in override mode
- 07-03: gitBinary parameter on all public git service functions — enables Homebrew git path configuration from AppConfig
- 07-01: Generated app_database.g.dart committed to git (not gitignored) — avoids build_runner as prerequisite for every build
- 07-01: AppDatabase accepts optional QueryExecutor — NativeDatabase.memory() injectable for unit tests without filesystem
- 07-01: getConfig() uses insert-then-select pattern for id=1 default row — ensures row always exists before updateConfig() writes
- 06-03: Release .app confirmed passing all NAT-01 through NAT-04 requirements — Phase 6 complete
- 06-03: Both entitlement files verified sandbox=false in codesigned binary — two-entitlements-file trap successfully avoided
- 06-01: Flutter installed via homebrew at `/opt/homebrew/share/flutter` (not `/Users/rob/code/flutter` as .zshrc expected) — update .zshrc or use full path
- 06-01: Entitlement files are `DebugProfile.entitlements` / `Release.entitlements` (Flutter 3.41.1, no `Runner-` prefix)
- 06-01: `applicationSupportsSecureRestorableState` must be kept in AppDelegate — Flutter build warns if removed
- 06-02: `trayManager.ensureInitialized()` does not exist in tray_manager 0.5.2 — TrayService.init() handles all setup
- 06-02: `MenuItem` imported directly from tray_manager; no need to hide from flutter/material.dart
- 06-02: `dart:ui` must be imported explicitly for `Size` and `Offset` types in window_geometry_service.dart

### Pending Todos

- Update ~/.zshrc to add `/opt/homebrew/share/flutter/bin` to PATH (or symlink to expected `/Users/rob/code/flutter`)

### Blockers/Concerns

- ~~Phase 6: `tray_manager` + `window_manager` version compatibility~~ — RESOLVED: tray_manager 0.5.2 + window_manager 0.5.1 both installed, flutter build macos succeeds
- ~~Phase 8: dart-lang/watcher#79 (isDirectory assertion crash)~~ — RESOLVED: Fixed in watcher 1.2.1; WatcherService also adds handleError defensive guard per locked decision

## Session Continuity

Last session: 2026-02-19
Stopped at: Completed 08-01-PLAN.md — WatcherService with StreamController.broadcast() re-broadcast pattern, 350ms debounce, 4 integration tests
Resume file: .planning/milestones/v1.1-phases/08-watcher/08-02-PLAN.md
