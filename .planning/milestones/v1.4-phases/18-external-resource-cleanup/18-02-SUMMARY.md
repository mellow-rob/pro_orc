---
phase: 18-external-resource-cleanup
plan: 02
subsystem: ui
tags: [flutter, dialog, external-resources, notion, github, figma, claude-memory, glassmorphism, checkbox]

requires:
  - phase: 18-01
    provides: "ExternalResource model and detectExternalResources() service"
  - phase: 17-deletion-core
    provides: "DeleteProjectDialog baseline with glassmorphism styling and name-confirmation flow"
provides:
  - "Enhanced DeleteProjectDialog with non-blocking resource detection in initState"
  - "Per-resource checkboxes (unchecked by default) between warning box and name input"
  - "Post-deletion summary screen with full URI and hint text for each marked resource"
affects: []

tech-stack:
  added: []
  patterns:
    - "Non-blocking resource loading in initState: async call sets state, does not block dialog open"
    - "Show-summary pattern: after deletion, replace dialog body with cleanup guidance instead of immediate pop"
    - "Conditional section rendering: resource list section only rendered when _resources != null && isNotEmpty"

key-files:
  created: []
  modified:
    - pro_orc/lib/features/shared/delete_project_dialog.dart

key-decisions:
  - "Resource list shown only when resources exist — zero-resource case is identical to Phase 17 dialog (no empty-state clutter)"
  - "Post-deletion summary replaces dialog body in-place via _showSummary flag — avoids push/pop gymnastics"
  - "Checkboxes unchecked by default (CLN-05): user must explicitly opt-in before seeing cleanup summary"

patterns-established:
  - "Hint text shown inline below URI for checked resources (amber color) — provides context without clutter"
  - "_iconForType switch covers all 5 ExternalResourceType values with appropriate Material icons"

requirements-completed: [CLN-01, CLN-02, CLN-03, CLN-04, CLN-05]

duration: 1min
completed: 2026-02-27
---

# Phase 18 Plan 02: DeleteProjectDialog Resource UI Summary

**DeleteProjectDialog extended with non-blocking external resource detection, per-resource checkboxes (unchecked by default), and a post-deletion cleanup summary screen showing full URI and German hint text for each marked resource**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-27T14:04:43Z
- **Completed:** 2026-02-27T14:06:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Resource list renders between warning box and project name section when detectExternalResources() returns results
- Each resource row: checkbox (unchecked by default), type icon, label, truncated URI (50 chars), inline hint when checked
- Post-deletion summary screen replaces dialog body when any resources were selected — shows full URI + hint per resource
- Zero-resource case: dialog is pixel-identical to Phase 17 baseline (no empty-state section)
- All 5 ExternalResourceType values mapped to distinct Material icons

## Task Commits

Each task was committed atomically:

1. **Task 1: Add resource detection and checkbox UI to DeleteProjectDialog** - `29c997d` (feat)

## Files Created/Modified

- `pro_orc/lib/features/shared/delete_project_dialog.dart` - Extended with _resources state, _selectedResources set, _showSummary flag, _buildResources(), _buildSummary(), _iconForType()

## Decisions Made

- Resource list rendered only when `_resources != null && _resources!.isNotEmpty` — the null guard means loading silently (dialog is usable immediately), and the empty guard means no UI change when no resources found
- Summary screen built via `_showSummary` flag toggling between `_buildMainForm()` and `_buildSummary()` in build() — simpler than pushing a new route
- Checkboxes default unchecked per CLN-05 — user must explicitly select resources before seeing the summary

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing flutter analyze warnings in gsd_parser.dart, settings_tab.dart, launch_dialog.dart, and test files (14 total, including 1 error in widget_test.dart). All pre-exist from prior phases. New file has zero analyzer issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 18 complete: ExternalResource model, detectExternalResources() service, and extended DeleteProjectDialog all delivered
- All CLN-01 through CLN-05 requirements satisfied
- No blockers

---
*Phase: 18-external-resource-cleanup*
*Completed: 2026-02-27*

## Self-Check: PASSED

- FOUND: pro_orc/lib/features/shared/delete_project_dialog.dart
- FOUND: .planning/phases/18-external-resource-cleanup/18-02-SUMMARY.md
- FOUND: commit 29c997d (Task 1)
