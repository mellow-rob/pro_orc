# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-19)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 6 — Native Foundation (v1.1)

## Current Position

Phase: 6 of 11 (Native Foundation)
Plan: — (not yet planned)
Status: Ready to plan
Last activity: 2026-02-19 — v1.1 roadmap created, 6 phases defined, 29 requirements mapped

Progress: [░░░░░░░░░░░░░░░░░░░░] 0% (v1.1)

## Performance Metrics

**Velocity (v1.0 reference):**
- Total plans completed: 12
- Average duration: ~2 min/plan
- Total execution time: ~0.35 hours

**v1.1 Velocity:**
- Plans completed: 0
- (Will track after Phase 6 begins)

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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 6: `tray_manager` + `window_manager` version compatibility must be verified before starting — check against community menubar template
- Phase 8: dart-lang/watcher#79 (isDirectory assertion crash) — check if fixed in current package version before building watcher service

## Session Continuity

Last session: 2026-02-19
Stopped at: v1.1 roadmap written. Phase 6 is next — run /gsd:plan-phase 6
Resume file: None
