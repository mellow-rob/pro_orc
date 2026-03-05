---
phase: 20-folder-import
plan: 01
subsystem: data
tags: [dart, tdd, scaffolding, type-detection, path-analysis]

requires:
  - phase: 16-projekt-ersteller
    provides: project_creator_service.dart scaffolding logic, templates
  - phase: 07-data-layer
    provides: ProjectScanner._inferType, _codeMarkers
provides:
  - inferProjectType: shared type detection function
  - analyzeFolder + FolderAnalysis: scan-dir containment and file existence analysis
  - scaffoldProject + ScaffoldResult: skip-existing scaffolding with auto-commit
  - Public template functions (gsdProjectMd, claudeMdContent, gitignoreContent, etc.)
affects: [20-02, 20-03, 20-04]

tech-stack:
  added: []
  patterns: [shared-service-extraction, skip-existing-scaffolding, p.isWithin-containment]

key-files:
  created:
    - pro_orc/lib/data/services/project_importer_service.dart
    - pro_orc/test/data/project_importer_test.dart
  modified:
    - pro_orc/lib/data/services/project_scanner.dart
    - pro_orc/lib/data/services/project_creator_service.dart

key-decisions:
  - "Templates als public top-level functions statt separate scaffold_templates.dart"
  - "ProjectScanner delegiert _inferType via Wrapper-Methode an shared function"
  - "scaffoldProject auto-committed nur wenn .git existiert UND Dateien erstellt"

patterns-established:
  - "skip-existing pattern: check existsSync() before every file write in scaffolding"
  - "scan-dir containment: p.isWithin() with trailing slash normalization"

requirements-completed: [IMP-02, IMP-03, IMP-04, IMP-05]

duration: 5min
completed: 2026-03-05
---

# Phase 20 Plan 01: Importer Service Summary

**Shared project importer service with TDD: inferProjectType, analyzeFolder with p.isWithin scan-dir check, and scaffoldProject with skip-existing semantics**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-05T11:27:17Z
- **Completed:** 2026-03-05T11:32:14Z
- **Tasks:** 1 (TDD: RED + GREEN + REFACTOR)
- **Files modified:** 4

## Accomplishments
- Extracted type inference from ProjectScanner into shared inferProjectType function
- Created FolderAnalysis with scan-dir containment detection via p.isWithin
- Built scaffoldProject that never overwrites existing files and auto-commits only when appropriate
- Refactored project_creator_service to delegate scaffolding to shared function
- 31 new tests covering all behaviors, full suite green (1 pre-existing failure unrelated)

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing tests** - `952d33c` (test)
2. **Task 1 GREEN: Implementation + refactor** - `7ba9f61` (feat)

**Plan metadata:** [pending] (docs: complete plan)

_Note: TDD task with RED + GREEN commits_

## Files Created/Modified
- `pro_orc/lib/data/services/project_importer_service.dart` - New service: inferProjectType, analyzeFolder, scaffoldProject, templates
- `pro_orc/test/data/project_importer_test.dart` - 31 unit tests with real temp dirs
- `pro_orc/lib/data/services/project_scanner.dart` - Delegates _inferType to shared function, removed _codeMarkers
- `pro_orc/lib/data/services/project_creator_service.dart` - Delegates scaffolding to scaffoldProject, removed template functions

## Decisions Made
- Templates extracted as public top-level functions in importer service (not separate file) for simplicity
- ProjectScanner keeps `_inferType` wrapper method that delegates to shared function (minimal diff)
- scaffoldProject checks `.git` directory existence (not git command) for commit decisions
- createProject retains its own `_gitInitAndCommit` for the create flow (different commit message pattern)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored dart:async import in project_creator_service.dart**
- **Found during:** Task 1 GREEN (analyzer check)
- **Issue:** Removing old import header also removed `dart:async` needed by `TimeoutException`
- **Fix:** Re-added `import 'dart:async';`
- **Files modified:** pro_orc/lib/data/services/project_creator_service.dart
- **Verification:** `flutter analyze` returns zero issues
- **Committed in:** 7ba9f61 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial import fix, no scope creep.

## Issues Encountered
- Pre-existing test failure: `GsdParser truncates description to 200 characters` expects 200 but limit was raised to 500 in Phase 19. Not caused by this plan, not fixed (out of scope).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Importer service ready for Plan 02 (Import Dialog UI)
- analyzeFolder provides all data needed for smart defaults in dialog
- scaffoldProject provides all scaffolding needed post-confirmation

---
*Phase: 20-folder-import*
*Completed: 2026-03-05*
