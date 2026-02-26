---
phase: 15-project-creation
plan: 02
subsystem: ui
tags: [flutter, dart, wiring, terminal, osascript, riverpod, drift]

# Dependency graph
requires:
  - phase: 15-project-creation
    plan: 01
    provides: ProjectCreatorService and updated CreateProjectDialog with toggles

provides:
  - Fully wired Erstellen button calling ProjectCreatorService with spinner/success feedback
  - Post-creation Terminal and rem-sleep actions via osascript
  - Project type persistence in DB for correct scanner classification
  - Auto-close dialog after success with brief "Erstellt!" feedback

affects: [any feature reading project_settings_table]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Post-creation actions delegated to tab context (not dialog) to avoid mounted/lifecycle issues"
    - "DB upsertProjectSettings persists projectType so scanner bypasses _inferType heuristic"
    - "osascript without runInShell for reliable Terminal command execution from Flutter"
    - "_terminalScript helper for clean AppleScript string escaping"
    - "previousTabIndex tracking to prevent TabController listener from resetting toggles on unrelated setState"

key-files:
  modified:
    - pro_orc/lib/features/shared/create_project_dialog.dart
    - pro_orc/lib/features/code/code_tab.dart
    - pro_orc/lib/features/research/research_tab.dart
    - pro_orc/lib/data/services/quick_actions_service.dart

key-decisions:
  - "Post-creation actions (Terminal, rem-sleep) execute in tab, not dialog — dialog pops with action flags, tab handles execution"
  - "Project type persisted in DB immediately after creation — scanner uses DB override before _inferType heuristic"
  - "osascript without runInShell avoids double shell quoting issues"
  - "TabController listener tracks previousTabIndex to only reset toggles on actual tab change"

patterns-established:
  - "Dialog returns action flags via Map, caller executes side effects — clean lifecycle separation"
  - "New projects get DB projectType entry so content-based heuristic doesn't misclassify empty projects"

requirements-completed: [CRE-01, CRE-04, CRE-05]

# Metrics
duration: ~45min (including debugging 3 bugs)
completed: 2026-02-26
---

# Phase 15 Plan 02: Dialog Service Wiring + Post-Creation Actions Summary

**Wired CreateProjectDialog to ProjectCreatorService with loading spinner, success feedback, Terminal/rem-sleep post-creation actions, and automatic project type classification.**

## Performance

- **Duration:** ~45 min (3 bugs found and fixed during verification)
- **Started:** 2026-02-25
- **Completed:** 2026-02-26
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 4

## Accomplishments
- Erstellen button calls `createProject()` with spinner during creation and "Erstellt!" checkmark on success
- Dialog auto-closes after 1.5s (3s if warnings present)
- Terminal opens in new project directory via osascript `do script`
- rem-sleep runs `cd && claude /rem-sleep` in Terminal when toggled
- New project appears immediately in correct tab via DB `projectType` persistence + `ref.invalidate`
- Error feedback shown in dialog when creation fails

## Bugs Fixed During Verification

### Bug 1: Toggle values reset on every setState
- **Root cause:** `_onTabChanged` listener checked `!indexIsChanging` which is true even when no tab switch occurs — every `setState` rebuild triggered toggle reset to defaults
- **Fix:** Track `_previousTabIndex`, only reset when index actually changes

### Bug 2: New project not showing in correct tab
- **Root cause:** `_inferType()` checks for build files (pubspec.yaml, etc.) — empty new project has none, classified as `research` instead of `code`
- **Fix:** `upsertProjectSettings` with `projectType` in DB after creation, scanner uses DB override before heuristic

### Bug 3: Terminal commands not executing reliably
- **Root cause:** `Process.run` with `runInShell: true` caused double shell quoting of osascript arguments
- **Fix:** Removed `runInShell`, added `_terminalScript` helper for clean AppleScript escaping

## Task Commits

1. **Task 1: Wire Erstellen + post-creation actions** - `eab0ff9`, `760f2b9`, `ae3c491`
2. **Task 2: Visual verification** - Human-approved after bug fixes

## Files Modified
- `pro_orc/lib/features/shared/create_project_dialog.dart` - Wired _submit to createProject, previousTabIndex fix, action flags in pop result
- `pro_orc/lib/features/code/code_tab.dart` - DB projectType persistence, post-creation Terminal/rem-sleep execution
- `pro_orc/lib/features/research/research_tab.dart` - Same as code_tab for research context
- `pro_orc/lib/data/services/quick_actions_service.dart` - osascript without runInShell, _terminalScript helper

## Self-Check: PASSED

- [x] `pro_orc/lib/features/shared/create_project_dialog.dart` — contains `createProject` call
- [x] `pro_orc/lib/features/code/code_tab.dart` — contains `createProject` reference and DB persistence
- [x] `pro_orc/lib/features/research/research_tab.dart` — contains `createProject` reference and DB persistence
- [x] Commits present in git log
- [x] `flutter analyze` — no new issues
- [x] Human verification — approved by user
