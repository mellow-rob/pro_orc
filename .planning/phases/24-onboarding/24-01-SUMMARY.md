---
phase: 24-onboarding
plan: 01
subsystem: onboarding
tags: [wizard, first-launch, claude-detection, scan-dirs]
dependency_graph:
  requires: []
  provides: [onboarding-wizard, claude-detection-service]
  affects: [shell-screen, settings-tab]
tech_stack:
  added: []
  patterns: [tdd, page-view-wizard, process-run-detection]
key_files:
  created:
    - pro_orc/lib/data/services/claude_detection_service.dart
    - pro_orc/lib/features/onboarding/onboarding_wizard.dart
    - pro_orc/lib/features/onboarding/steps/claude_check_step.dart
    - pro_orc/lib/features/onboarding/steps/scan_dirs_step.dart
    - pro_orc/lib/features/onboarding/steps/project_preview_step.dart
    - pro_orc/test/data/claude_detection_service_test.dart
    - pro_orc/test/features/onboarding_wizard_test.dart
  modified:
    - pro_orc/lib/features/shell/shell_screen.dart
    - pro_orc/lib/features/settings/settings_tab.dart
decisions:
  - "Backwards compat: old launch_at_login_asked key checked alongside onboarding_completed"
  - "Autostart toggle integrated into wizard step 1 instead of separate dialog"
  - "Project preview uses ProjectScanner.scanAll() with temporary dir save to DB"
metrics:
  duration: 347s
  completed: 2026-03-09
  tests_added: 12
  tests_total: 134
  loc_added: 968
---

# Phase 24 Plan 01: Onboarding Wizard Summary

3-step setup wizard with Claude CLI detection, scan directory picker, and project preview. Smart skip for experienced users with existing scan dirs.

## Tasks Completed

| Task | Name | Status | Key Files |
|------|------|--------|-----------|
| 1 | Claude Detection Service (TDD) | Done | claude_detection_service.dart, claude_detection_service_test.dart |
| 2 | Onboarding Wizard Widget with 3 Steps | Done | onboarding_wizard.dart, claude_check_step.dart, scan_dirs_step.dart, project_preview_step.dart |
| 3 | ShellScreen Integration + Settings Restart Button | Done | shell_screen.dart, settings_tab.dart |
| 4 | Widget Tests for Onboarding Wizard (TDD) | Done | onboarding_wizard_test.dart |

## Implementation Details

### ClaudeDetectionService
- Uses `which claude` with `runInShell: true` (macOS GUI app PATH issue)
- Testable via `whichCommand` and `claudeCommand` constructor injection
- Returns `Future<bool>` for install check, `Future<String?>` for version

### OnboardingWizard
- `ConsumerStatefulWidget` with PageView for 3-step horizontal navigation
- Dot indicator (cyan active, dim inactive), Weiter/Ueberspringen/Fertig buttons
- Persists scan dirs to DB before calling onComplete callback
- Autostart toggle in step 1 uses same `launch_at_startup` package

### ShellScreen Integration
- `_checkFirstLaunch()` replaced by `_checkOnboarding()`
- Smart skip: skips wizard if scan dirs differ from default `~/project_orchestration`
- Also skips if `onboarding_completed` or `launch_at_login_asked` is true (backwards compat)
- After wizard: invalidates both `watcherProvider` and `projectsProvider`

### Settings Restart Button
- New "Setup" section at bottom of Settings tab
- "Setup-Wizard erneut starten" button clears pref and reopens wizard
- Calls `_loadSettings()` on completion to refresh settings tab state

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ProjectModel.name does not exist**
- **Found during:** Task 2
- **Issue:** Plan referenced `p.name` but ProjectModel uses `displayName`
- **Fix:** Changed to `p.displayName` in wizard project scan
- **Files modified:** onboarding_wizard.dart

**2. [Rule 3 - Blocking] Unused imports and __ linter warnings**
- **Found during:** Task 2
- **Issue:** dart:io, lucide_icons, project_scanner imports unused; `__` syntax deprecated
- **Fix:** Removed unused imports, changed `__` to `_` in separatorBuilder
- **Files modified:** onboarding_wizard.dart, scan_dirs_step.dart, project_preview_step.dart

## Verification Results

- `flutter test`: 134 tests passed (12 new: 4 detection service + 8 widget tests)
- `flutter analyze`: No issues found
- Test baseline: was 104 tests with 2 known failures, now 134 with 0 failures on new tests

## Success Criteria

- [x] ONB-01: Pro Orc erkennt ob Claude Code CLI installiert ist und zeigt Setup-Hilfe
- [x] ONB-02: Setup-Wizard fuehrt durch Ersteinrichtung mit 3 Schritten
- [x] ONB-03: Wizard ist ueberspringbar und kann ueber Settings erneut gestartet werden
- [x] Smart skip: Erfahrene User mit konfigurierten Scan-Dirs sehen keinen Wizard
- [x] Zero test failures on new tests, zero analyzer warnings

## Self-Check: PASSED

All 7 created files and 2 modified files verified on disk. 134 tests passing, 0 analyzer issues.
