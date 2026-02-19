---
phase: 06-native-foundation
plan: 03
subsystem: native-macos-shell
tags: [flutter, macos, release-build, sandbox, entitlements, codesign, NAT-validation]

dependency_graph:
  requires:
    - phase: 06-02
      provides: TrayService, WindowGeometryService, GlowBorderShell, ShellScreen — the full tray/window/shell behavior
  provides:
    - release-app-bundle-verified (flutter build macos confirmed working)
    - sandbox-disabled-in-release (codesign entitlements show false for both DebugProfile and Release)
    - NAT-01-through-NAT-04-human-verified (all four NAT requirements confirmed in built .app)
  affects:
    - Phase 7 and beyond (confirmed the built .app is the delivery vehicle, not just flutter run)

tech-stack:
  added: []
  patterns:
    - Release validation pattern: automate entitlement checks with codesign + pgrep, then gate on human verify for interactive NAT checks
    - Two-entitlements-file check: always verify both DebugProfile.entitlements and Release.entitlements show sandbox=false

key-files:
  created: []
  modified: []

key-decisions:
  - "Release .app passes all NAT-01 through NAT-04 requirements — Phase 6 is complete"
  - "Both entitlement files (DebugProfile and Release) confirmed sandbox=false in the codesigned binary"
  - "Manual verification confirmed: tray icon, hide-to-tray, geometry persistence, glow border all work in the release .app"

patterns-established:
  - "Release validation: run flutter build macos, check codesign entitlements, pgrep process start, LSUIElement in Info.plist, then human verify all interactive behaviors"

requirements-completed: [NAT-01, NAT-02, NAT-03, NAT-04]

duration: ~15min
completed: 2026-02-19
---

# Phase 06 Plan 03: Release Build and NAT Validation Summary

**Release .app bundle built and human-verified against all four NAT requirements: tray icon, hide-to-tray, geometry persistence, and sandbox-disabled filesystem access all confirmed in the codesigned binary**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-02-19T13:45:00Z
- **Completed:** 2026-02-19T14:03:00Z
- **Tasks:** 2
- **Files modified:** 0 (verification-only plan — no source files changed)

## Accomplishments

- `flutter build macos` succeeded — release .app bundle built without errors
- Automated sandbox validation passed all 5 checks: build exit 0, codesign entitlements sandbox=false, app process starts, LSUIElement=1, both entitlement source files show sandbox=false
- Human verification approved all 14 NAT checklist items covering NAT-01 through NAT-04
- Phase 6 (Native Foundation) is complete — all four NAT requirements satisfied

## Task Commits

Each task was committed atomically:

1. **Task 1: Build release .app and run automated sandbox validation** - `2510578` (chore)
2. **Task 2: Manual verification of all NAT requirements** - human-approved, no commit (checkpoint gate)

**Plan metadata:** *(this commit)* (docs: complete release build and NAT validation plan)

## Files Created/Modified

None — this plan was a verification plan only. All source files were created in plans 06-01 and 06-02.

## Decisions Made

- Release .app confirmed to pass all NAT-01 through NAT-04 requirements. Phase 6 is complete.
- Both entitlement files verified: `DebugProfile.entitlements` and `Release.entitlements` both show `<false/>` for `com.apple.security.app-sandbox` — the two-entitlements-file trap (identified in pre-build architectural decisions) was successfully avoided.

## Deviations from Plan

None — plan executed exactly as written. All automated checks passed on first attempt, human verification approved all 14 items.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 6 is complete. All NAT requirements (NAT-01 through NAT-04) are satisfied in the release binary.
- Phase 7 (Project Detection) can begin. ShellScreen is the live base widget tree.
- Reminder: Phase 7 must use `runInShell: true` on all `Process.run` calls — GUI app PATH does not include Homebrew git (pre-build architectural decision).
- Reminder: Check dart-lang/watcher#79 (isDirectory assertion crash) before building watcher service in Phase 8.

---
*Phase: 06-native-foundation*
*Completed: 2026-02-19*
