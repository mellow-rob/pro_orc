# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-19)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 6 — Native Foundation (v1.1)

## Current Position

Phase: 6 of 11 (Native Foundation) — COMPLETE
Plan: 3 of 3 complete (06-03 complete — all NAT requirements verified in release .app)
Status: Phase 6 complete — ready for Phase 7
Last activity: 2026-02-19 — Phase 6, Plan 03 complete (release .app built and all NAT requirements human-verified)

Progress: [####░░░░░░░░░░░░░░░░] ~15% (v1.1, 3/~20 plans complete)

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
- Phase 9: All OKLCH design tokens must be pre-converted to sRGB hex before Phase 9 begins (use oklch.com)

**v1.1 decisions made during execution:**
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
- Phase 8: dart-lang/watcher#79 (isDirectory assertion crash) — check if fixed in current package version before building watcher service

## Session Continuity

Last session: 2026-02-19
Stopped at: Phase 6, Plan 03 complete. Phase 6 (Native Foundation) fully complete. Next: run /gsd:execute-phase 07
Resume file: .planning/milestones/v1.1-phases/06-native-foundation/06-03-SUMMARY.md
