---
phase: 15-project-creation
plan: 01
subsystem: ui
tags: [flutter, dart, filesystem, git, scaffolding, dialog]

# Dependency graph
requires:
  - phase: 14-add-card-dialog
    provides: CreateProjectDialog glassmorphism shell with AnimatedSwitcher toggle sections

provides:
  - ProjectCreatorService pure Dart service with createProject() and ProjectCreationResult
  - Updated CreateProjectDialog with kebab-case derivation, full path preview, CLAUDE.md/Terminal/.gitignore toggles
  - rem-sleep / Terminal toggle dependency enforcement
  - Non-writable scan dir filtering
  - Expanded _submit return map with claudeMd, terminal, gitignoreTemplate fields

affects: [15-02-wiring, any phase reading dialog return values]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Top-level function service pattern (createProject) matching git_reader.dart / memory_reader.dart"
    - "_runWithTimeout Future.any race with 5s timeout for Process.run calls"
    - "Warnings-not-failures: only directory creation fails the operation; all other steps add to warnings list"
    - "Non-writable dir detection via try-create-delete temp file in _isWritable()"
    - "Single scan dir hides dropdown (auto-selected, cleaner UX)"

key-files:
  created:
    - pro_orc/lib/data/services/project_creator_service.dart
  modified:
    - pro_orc/lib/features/shared/create_project_dialog.dart

key-decisions:
  - "ProjectCreatorService import omitted from dialog until Phase 15-02 wires the actual call (unused import warning)"
  - "gitignore dropdown uses initialValue not deprecated value parameter"
  - "Toggle section height increased to 190px (5 toggles + dropdown) with AnimatedSwitcher for smooth tab transition"
  - "Single scan dir hides Zielordner dropdown per context decision"
  - "rem-sleep forces Terminal ON; Terminal OFF cascades to rem-sleep OFF (both tabs)"

patterns-established:
  - "Warnings-not-failures: collect non-fatal errors in List<String> warnings, only fail on directory creation"
  - "runInShell: true on all Process.run calls (macOS GUI PATH requirement)"

requirements-completed: [CRE-01, CRE-02, CRE-03, CRE-06, CRE-07]

# Metrics
duration: 3min
completed: 2026-02-25
---

# Phase 15 Plan 01: Project Creator Service + Dialog Updates Summary

**Pure Dart ProjectCreatorService with full filesystem scaffolding (git/GSD/.gitignore/CLAUDE.md) plus dialog UI updates for kebab-case paths, full path preview, 5 new toggles, and rem-sleep/Terminal dependency enforcement.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-25T11:50:59Z
- **Completed:** 2026-02-25T11:53:48Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `ProjectCreatorService` pure Dart service: creates project dir, optional GSD skeleton (4 .planning/ files), CLAUDE.md, .gitignore from template, research README.md, git init + initial commit — failures collected as warnings, never abort
- `CreateProjectDialog` updated: kebab-case derivation (spaces/underscores → hyphens), full path preview (~/code/mein-projekt), CLAUDE.md + Terminal + .gitignore toggles for Code tab, Terminal toggle for Research tab
- rem-sleep / Terminal dependency: rem-sleep ON forces Terminal ON; Terminal OFF cascades to rem-sleep OFF (both Code and Research tabs)
- Non-writable scan dirs filtered from dropdown; single scan dir hides dropdown

## Task Commits

Each task was committed atomically:

1. **Task 1: ProjectCreatorService** - `eb7714a` (feat)
2. **Task 2: Update CreateProjectDialog** - `ff1ccc4` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `pro_orc/lib/data/services/project_creator_service.dart` - Pure Dart service: createProject(), ProjectCreationResult, git helpers, file templates
- `pro_orc/lib/features/shared/create_project_dialog.dart` - Updated dialog: kebab-case, full path preview, 3 new toggles (Code), 1 new toggle (Research), .gitignore dropdown, rem-sleep/Terminal dependency

## Decisions Made
- Kept ProjectCreatorService import out of dialog until Phase 15-02 wires the actual call — avoids unused import warning
- Used `initialValue` (not deprecated `value`) on gitignore DropdownButtonFormField
- Toggle section height 190px covers Code tab worst case (5 toggles + dropdown); AnimatedSwitcher handles visual transition between tab layouts
- `_isWritable()` uses try-create-delete temp file approach (reliable, cross-platform)
- Single scan dir hides dropdown per context decisions (auto-selected)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unused import warning from ProjectCreatorService**
- **Found during:** Task 2 (Dialog update)
- **Issue:** Imported `project_creator_service.dart` but Phase 15-02 wires the actual call — `flutter analyze` flagged unused import warning
- **Fix:** Removed import from dialog; will be added in Phase 15-02 when the service call is wired
- **Files modified:** pro_orc/lib/features/shared/create_project_dialog.dart
- **Verification:** `flutter analyze` reports no issues
- **Committed in:** ff1ccc4 (Task 2 commit)

**2. [Rule 1 - Bug] Fixed deprecated `value` parameter on DropdownButtonFormField**
- **Found during:** Task 2 (gitignore dropdown implementation)
- **Issue:** Used deprecated `value:` parameter; `flutter analyze` flagged `deprecated_member_use` info
- **Fix:** Changed to `initialValue:` (non-deprecated API)
- **Files modified:** pro_orc/lib/features/shared/create_project_dialog.dart
- **Verification:** `flutter analyze` reports no issues
- **Committed in:** ff1ccc4 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - small API correctness fixes during Task 2)
**Impact on plan:** Both fixes necessary for clean `flutter analyze`. No scope creep.

## Issues Encountered
None - both tasks executed cleanly after two minor auto-fixes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ProjectCreatorService and updated dialog return map ready for Phase 15-02 wiring
- Phase 15-02 needs to: import ProjectCreatorService in dialog, call createProject() on _submit, show spinner, handle warnings, auto-close on success
- Terminal/rem-sleep launch logic (osascript) also for Phase 15-02

---
*Phase: 15-project-creation*
*Completed: 2026-02-25*

## Self-Check: PASSED

- [x] `pro_orc/lib/data/services/project_creator_service.dart` — exists (347 lines, requirement: min 120)
- [x] `.planning/phases/15-project-creation/15-01-SUMMARY.md` — exists
- [x] Commit `eb7714a` (Task 1) — verified in git log
- [x] Commit `ff1ccc4` (Task 2) — verified in git log
- [x] `flutter analyze` — no issues on both new/modified files
