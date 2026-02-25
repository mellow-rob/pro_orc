---
phase: 14-add-card-dialog
plan: 02
subsystem: ui
tags: [flutter, dialog, riverpod, glassmorphism, tabbar, form-validation]

# Dependency graph
requires:
  - phase: 14-01
    provides: AddProjectCard widget + _openCreateDialog stub in Code and Research tabs
provides:
  - CreateProjectDialog widget with TabBar, name field, toggles, Zielordner dropdown
  - Wired _openCreateDialog in code_tab.dart and research_tab.dart
affects: [15-project-creation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AnimatedSwitcher for tab-driven content transitions (200ms fade)
    - AnimatedBuilder wrapping TabBar for dynamic accent color changes
    - ConsumerStatefulWidget with SingleTickerProviderStateMixin for TabController + Riverpod access
    - BackdropFilter + Container manual glassmorphism (same pattern as GlassCard)
    - initialValue on DropdownButtonFormField (not deprecated value)
    - activeThumbColor + activeTrackColor on SwitchListTile.adaptive (not deprecated activeColor)

key-files:
  created:
    - pro_orc/lib/features/shared/create_project_dialog.dart
  modified:
    - pro_orc/lib/features/code/code_tab.dart
    - pro_orc/lib/features/research/research_tab.dart

key-decisions:
  - "SwitchListTile.adaptive with activeThumbColor/activeTrackColor — avoids deprecated activeColor API"
  - "AnimatedSwitcher keyed on tab index for toggle group transition — clean fade without extra animation controller"
  - "AnimatedBuilder wrapping TabBar reads _tabController.index for accent color — rebuilds only when tab animates"
  - "Toggles reset to tab defaults on tab switch completion (indexIsChanging guard)"
  - "_isLoading kept as mutable field (ignore: prefer_final_fields) for Phase 15 spinner use"

patterns-established:
  - "Dialog glassmorphism: Dialog(backgroundColor: transparent) + ClipRRect + BackdropFilter + Container(bgSurf)"
  - "Folder name derivation: trim -> lowercase -> spaces to underscores -> strip non-[a-z0-9_-]"
  - "Path abbreviation: replace HOME prefix with ~ using Platform.environment['HOME']"

requirements-completed: [ADD-03, ADD-04, DLG-01, DLG-02, DLG-03, DLG-04, DLG-05]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 14 Plan 02: CreateProjectDialog Summary

**Flutter dialog with Code/Research TabBar, live folder name derivation, per-tab toggle defaults, and Zielordner dropdown wired into both tabs**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-25T08:31:31Z
- **Completed:** 2026-02-25T08:34:00Z
- **Tasks:** 3 of 3 complete (checkpoint approved after UI polish)
- **Files modified:** 5

## Accomplishments
- `CreateProjectDialog` (464 lines) with glassmorphism style, TabBar, name field with live folder preview and existence check, Zielordner dropdown loading from DB, per-tab toggles with correct defaults, and disabled Erstellen button when invalid
- `_openCreateDialog` wired in both code_tab.dart and research_tab.dart via `showDialog<Map<String, dynamic>>`
- UI polish after visual verification: add card shows only "+" icon (no "Neu" text), toggle switches use white color with FittedBox for smaller size, dialog toggle section height fixed to prevent resize on tab switch
- `flutter analyze` reports zero issues on new/modified files; pre-existing issues only in unrelated files

## Task Commits

Each task was committed atomically:

1. **Task 1: CreateProjectDialog Widget** - `1f8d385` (feat)
2. **Task 2: Wire Dialog into Code and Research tabs** - `57cf320` (feat)
3. **Task 3: Visual Verification (UI polish)** - `4941225` (fix)

**Plan metadata:** `0603569` (docs: complete CreateProjectDialog plan summary and state update)

## Files Created/Modified
- `pro_orc/lib/features/shared/create_project_dialog.dart` - CreateProjectDialog ConsumerStatefulWidget with full form UI; UI polish: FittedBox toggles, fixed height toggle section
- `pro_orc/lib/features/code/code_tab.dart` - Import + wired _openCreateDialog with showDialog call
- `pro_orc/lib/features/research/research_tab.dart` - Import + wired _openCreateDialog with showDialog call
- `pro_orc/lib/features/shared/add_project_card.dart` - Simplified to only "+" icon, removed "Neu" label text

## Decisions Made
- Used `AnimatedSwitcher` keyed on tab index for toggle group transitions — avoids second animation controller
- Used `AnimatedBuilder` wrapping TabBar to dynamically update indicator color without rebuilding entire widget tree
- Kept `_isLoading` as mutable field (not final) for Phase 15 spinner wiring
- Used `activeThumbColor` + `activeTrackColor` instead of deprecated `activeColor` on SwitchListTile.adaptive
- Used `initialValue` instead of deprecated `value` on DropdownButtonFormField

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed 3 deprecated API usages caught by flutter analyze**
- **Found during:** Task 1 (CreateProjectDialog Widget)
- **Issue:** `DropdownButtonFormField.value` deprecated (use `initialValue`); `SwitchListTile.adaptive.activeColor` deprecated (use `activeThumbColor`/`activeTrackColor`); `_isLoading` flagged as prefer_final_fields
- **Fix:** Replaced deprecated APIs; added `// ignore: prefer_final_fields` on `_isLoading` (needed mutable for Phase 15)
- **Files modified:** pro_orc/lib/features/shared/create_project_dialog.dart
- **Verification:** `flutter analyze` reports No issues found
- **Committed in:** `1f8d385` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug/deprecated API)
**Impact on plan:** Necessary API corrections. No scope creep.

## Issues Encountered
None beyond the deprecated API fixes handled automatically.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- CreateProjectDialog fully functional UI, visually verified and approved — ready for Phase 15 filesystem creation wiring
- Dialog returns `Map<String, dynamic>` with all form values: name, folderName, scanDir, tab, gitInit, gsdSkeleton, notion, remSleep
- Phase 14 plan 03 (settings UI for target directories) remains before Phase 15

---
*Phase: 14-add-card-dialog*
*Completed: 2026-02-25*
