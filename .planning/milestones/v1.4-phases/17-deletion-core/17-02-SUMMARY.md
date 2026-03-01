---
phase: 17-deletion-core
plan: 02
subsystem: ui
tags: [deletion, dialog, confirmation, flutter, riverpod]

# Dependency graph
requires:
  - "deletion_service.dart (deleteProject function) from 17-01"
  - "_confirmDelete() stubs in both card states from 17-01"
provides:
  - "DeleteProjectDialog — GitHub-style confirmation dialog requiring exact project name before enabling delete"
  - "Wired _confirmDelete() in CodeProjectCard showing DeleteProjectDialog"
  - "Wired _confirmDelete() in ResearchProjectCard showing DeleteProjectDialog"
affects: [18-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dialog calls deleteProject + ref.invalidate(projectsProvider) directly — card only shows dialog, no return value handling"
    - "TextEditingController.addListener triggers setState for real-time button enable/disable without form rebuilds"
    - "showDialog<bool> with builder: (_) => Widget() — ConsumerWidget receives its own ref, no ProviderScope needed"

key-files:
  created:
    - pro_orc/lib/features/shared/delete_project_dialog.dart
  modified:
    - pro_orc/lib/features/code/code_project_card.dart
    - pro_orc/lib/features/research/research_project_card.dart

key-decisions:
  - "Dialog owns deletion logic (deleteProject + invalidate) — card is a thin show-dialog caller, consistent with project's service ownership pattern"
  - "builder: (_) => DeleteProjectDialog() — underscore context discards builder context; dialog uses its own ConsumerState ref for provider access"
  - "Red FilledButton disabled until exact match — disabled style uses textDim.withValues(alpha:0.2) for clear visual distinction"

patterns-established:
  - "Destructive dialogs are ConsumerStatefulWidgets that own their side effects (delete + invalidate) — no callbacks needed to parent"

requirements-completed: [DEL-03, DEL-05]

# Metrics
duration: 2min
completed: 2026-02-27
---

# Phase 17 Plan 02: Confirmation Dialog Summary

**GitHub-style DeleteProjectDialog (exact name match required) wired into Code and Research cards, with deleteProject + ref.invalidate for auto-dashboard-refresh**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-27T12:16:55Z
- **Completed:** 2026-02-27T12:18:17Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `delete_project_dialog.dart` — ConsumerStatefulWidget with BackdropFilter blur background matching `create_project_dialog` style; TextEditingController with addListener for real-time exact-match checking; "Loeschen" FilledButton disabled (dimmed) until typed text matches `project.displayName` exactly; red warning box; calls `deleteProject` + `ref.invalidate(projectsProvider)` + pop on confirm
- Wired `_confirmDelete()` in `code_project_card.dart` — replaced stub with `showDialog<bool>` opening `DeleteProjectDialog`
- Wired `_confirmDelete()` in `research_project_card.dart` — same pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create DeleteProjectDialog** - `26debe1` (feat)
2. **Task 2: Wire _confirmDelete in both cards** - `b91316c` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `pro_orc/lib/features/shared/delete_project_dialog.dart` - Full GitHub-style confirmation dialog; 244 lines; exact name match gates the delete button
- `pro_orc/lib/features/code/code_project_card.dart` - Added delete_project_dialog import; replaced _confirmDelete stub with showDialog call
- `pro_orc/lib/features/research/research_project_card.dart` - Added delete_project_dialog import; replaced _confirmDelete stub with showDialog call

## Decisions Made
- Dialog is the authoritative owner of deletion side effects (deleteProject + invalidate) — the card widget is a thin caller. This is consistent with the project's pattern where services own their consequences.
- `builder: (_) => DeleteProjectDialog(project: widget.project)` — the underscore discards the builder's context; the dialog is a ConsumerStatefulWidget so it gets its own Riverpod ref through ConsumerState, requiring no ProviderScope wrapper.
- Disabled button uses `colors.textDim.withValues(alpha: 0.2)` for the background — clearly greyed out, distinctly different from the enabled `Colors.red.shade700`.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None

## Next Phase Readiness
- v1.4 Projekt-Loeschfunktion feature complete: deletion service (17-01) + confirmation dialog (17-02) fully wired
- Phase 18 (polish) can proceed — all DEL requirements satisfied: DEL-01, DEL-02, DEL-03, DEL-04, DEL-05

## Self-Check: PASSED

- FOUND: pro_orc/lib/features/shared/delete_project_dialog.dart
- FOUND: pro_orc/lib/features/code/code_project_card.dart (modified)
- FOUND: pro_orc/lib/features/research/research_project_card.dart (modified)
- FOUND: commit 26debe1 (Task 1 — DeleteProjectDialog)
- FOUND: commit b91316c (Task 2 — wire _confirmDelete)

---
*Phase: 17-deletion-core*
*Completed: 2026-02-27*
