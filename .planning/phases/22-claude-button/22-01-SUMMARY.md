---
phase: 22-claude-button
plan: 01
subsystem: ui/quick-actions
tags: [claude-button, quick-actions, context-menu, tdd]
dependency_graph:
  requires: []
  provides: [openClaude-service, claude-button-widget, terminal-context-menu]
  affects: [code_project_card, research_project_card, quick_actions, project_context_menu]
tech_stack:
  added: []
  patterns: [TextButton.icon, osascript-terminal-launch]
key_files:
  created:
    - pro_orc/test/data/services/quick_actions_service_test.dart
  modified:
    - pro_orc/lib/data/services/quick_actions_service.dart
    - pro_orc/lib/features/shared/quick_actions.dart
    - pro_orc/lib/features/shared/project_context_menu.dart
    - pro_orc/lib/features/code/code_project_card.dart
    - pro_orc/lib/features/research/research_project_card.dart
decisions:
  - "Claude button uses cyan on both Code and Research cards (CLB-02 locked decision)"
  - "buildClaudeScript() exposed as public method for testability instead of making _terminalScript public"
metrics:
  duration: "5 min"
  completed: "2026-03-09T13:28:00Z"
  tasks_completed: 2
  tasks_total: 2
  tests_added: 2
  tests_total: 106
  analyzer_warnings: 0
---

# Phase 22 Plan 01: Claude-Button Summary

Prominent Claude-Button auf allen Projektkarten via osascript + Terminal.app, Terminal-Button ins Kontextmenue verschoben.

## What Was Built

### Task 1: Service method + quick actions + context menu (TDD)

- Added `buildClaudeScript(path)` and `openClaude(path)` to `QuickActionsService`
- `openClaude` uses same osascript pattern as existing `openInTerminal` but appends `&& claude`
- Removed Terminal entry from `buildProjectQuickActions()` quick action row
- Added "Terminal" option to right-click context menu in `project_context_menu.dart`
- 2 unit tests: correct AppleScript generation, path-with-spaces handling

### Task 2: Prominent Claude button on both card types

- Added `_buildClaudeButton(colors)` method to both `CodeProjectCard` and `ResearchProjectCard`
- Button: cyan `TextButton.icon` with sparkles icon, "Claude" label, 32px height
- Positioned above quick action row (primary action prominence)
- Both card types use `colors.cyan` (not fuchsia on Research cards)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test expectations for AppleScript quote escaping**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** Tests expected unescaped quotes in AppleScript output, but `_terminalScript` escapes `"` to `\"` for AppleScript string safety
- **Fix:** Updated test expectations to use raw strings with escaped quotes
- **Files modified:** pro_orc/test/data/services/quick_actions_service_test.dart
- **Commit:** 0322d3c (included in Task 1 commit)

## Verification Results

- `flutter test`: 106/106 passed (2 new tests added)
- `flutter analyze`: No issues found
- CLB-01: openClaude generates correct `cd "path" && claude` AppleScript
- CLB-02: Claude button is cyan TextButton.icon with sparkles, above quick action row
- CLB-03: Terminal removed from quick actions, added to context menu

## Commits

| Task | Commit  | Description                                               |
| ---- | ------- | --------------------------------------------------------- |
| 1    | 0322d3c | Add openClaude service, move Terminal to context menu     |
| 2    | d397d6f | Add prominent Claude button to Code and Research cards    |

## Self-Check: PASSED

All 6 created/modified files verified on disk. Both task commits (0322d3c, d397d6f) found in git log.
