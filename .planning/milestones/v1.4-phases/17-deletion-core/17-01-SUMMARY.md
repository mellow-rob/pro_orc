---
phase: 17-deletion-core
plan: 01
subsystem: ui
tags: [deletion, context-menu, dart-io, flutter, services]

# Dependency graph
requires: []
provides:
  - "deletion_service.dart with deleteProject(String) top-level function using Directory.delete(recursive: true)"
  - "Code card context menu: 'Projekt loeschen' as last item with divider separator"
  - "Research card context menu: 'Projekt loeschen' as last item with divider separator"
  - "_confirmDelete() stub in both card states, ready for 17-02 wiring"
affects: [17-02-confirmation-dialog]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deletion service follows top-level function pattern (like memory_reader, git_reader) — no class wrapper"
    - "_confirmDelete() stub with no BuildContext param avoids use_build_context_synchronously lint across async .then() gaps"

key-files:
  created:
    - pro_orc/lib/data/services/deletion_service.dart
  modified:
    - pro_orc/lib/features/code/code_project_card.dart
    - pro_orc/lib/features/research/research_project_card.dart

key-decisions:
  - "_confirmDelete() takes no context parameter — avoids BuildContext across async gap lint; uses this.context when wired in 17-02"
  - "Deletion service returns bool (not exception) — consistent with project's error handling convention"

patterns-established:
  - "Destructive context menu entries separated by PopupMenuDivider and placed last"

requirements-completed: [DEL-01, DEL-02, DEL-04]

# Metrics
duration: 2min
completed: 2026-02-27
---

# Phase 17 Plan 01: Deletion Core Summary

**Pure Dart deleteProject service (rm -rf via Directory.delete recursive) and 'Projekt loeschen' context menu entries on both Code and Research cards**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-27T12:13:13Z
- **Completed:** 2026-02-27T12:14:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `deletion_service.dart` with top-level `deleteProject(String)` function that permanently deletes directories via `Directory.delete(recursive: true)`, returns bool
- Added "Projekt loeschen" as last context menu item with `PopupMenuDivider` separator in both `code_project_card.dart` and `research_project_card.dart`
- Added `_confirmDelete()` stub in both card states ready for dialog wiring in plan 17-02

## Task Commits

Each task was committed atomically:

1. **Task 1: Create deletion service** - `01b8d13` (feat)
2. **Task 2: Add context menu entries** - `cac7cc7` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `pro_orc/lib/data/services/deletion_service.dart` - Pure Dart service; top-level deleteProject function, rm -rf via Directory API
- `pro_orc/lib/features/code/code_project_card.dart` - Added divider + 'Projekt loeschen' item and _confirmDelete() stub
- `pro_orc/lib/features/research/research_project_card.dart` - Added divider + 'Projekt loeschen' item and _confirmDelete() stub

## Decisions Made
- `_confirmDelete()` takes no `BuildContext` parameter — the `.then()` callback is async-gapped and passing context there triggers `use_build_context_synchronously` lint. The stub uses `this.context` (State getter) when it gets wired in 17-02.
- Deletion service returns `bool` on success/failure, never throws — consistent with project convention (`GitData.empty`, `MemoryData` null returns).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed BuildContext parameter from _confirmDelete stub**
- **Found during:** Task 2 (context menu entries)
- **Issue:** Plan specified `_confirmDelete(context)` with context passed from `.then()` callback — triggers `use_build_context_synchronously` lint (analyzer error level info, but breaks clean analyze goal)
- **Fix:** Changed signature to `_confirmDelete()` with no param; stub body comments that it will use `this.context` in 17-02
- **Files modified:** code_project_card.dart, research_project_card.dart
- **Verification:** `flutter analyze` passes with no issues on both files
- **Committed in:** cac7cc7 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - lint/correctness)
**Impact on plan:** Minor signature change only. The `_confirmDelete()` method is a stub; 17-02 will implement the body using `this.context` which is available as the State's context getter.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `deleteProject()` service is ready for use in 17-02 confirmation dialog
- Both card stubs `_confirmDelete()` are wired to the 'delete' menu value — 17-02 only needs to fill in the dialog body

---
*Phase: 17-deletion-core*
*Completed: 2026-02-27*
