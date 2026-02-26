---
phase: 16-notion-via-claude
plan: 01
subsystem: ui
tags: [flutter, notion, claude-code, terminal, osascript, quick-actions]

# Dependency graph
requires:
  - phase: 15-project-creation
    provides: CreateProjectDialog, ResearchTab _openCreateDialog, QuickActionsService with openRemSleep/openInTerminal
provides:
  - openClaudeWithPrompt method in QuickActionsService
  - wantsNotion and displayName in CreateProjectDialog pop result
  - Notion-priority post-creation action in ResearchTab
affects: [future post-creation action extensions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shell prompt escaping: single-quote wrap with internal quote escape via replaceAll(\"'\", \"'\\\\''\")"
    - "Notion takes priority over Terminal/rem-sleep — Claude Code opens Terminal implicitly"

key-files:
  created: []
  modified:
    - pro_orc/lib/data/services/quick_actions_service.dart
    - pro_orc/lib/features/shared/create_project_dialog.dart
    - pro_orc/lib/features/research/research_tab.dart

key-decisions:
  - "wantsNotion takes priority over wantsTerminal/wantsRemSleep — Claude Code already opens a Terminal window"
  - "German prompt instructs Claude to create Notion page via MCP and write URL as HTML comment in PROJECT.md"
  - "Shell single-quote escaping used for prompt (not double-quote) to handle German text with special characters"

patterns-established:
  - "Post-creation action priority: wantsNotion > wantsRemSleep > wantsTerminal"

requirements-completed:
  - NOT-01
  - NOT-02

# Metrics
duration: 2min
completed: 2026-02-26
---

# Phase 16 Plan 01: Notion-via-Claude Summary

**Notion page creation via Claude Code MCP: research project creation launches Claude in Terminal with German prompt to create Notion page and write URL to PROJECT.md**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-26T11:35:44Z
- **Completed:** 2026-02-26T11:37:31Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `openClaudeWithPrompt(projectPath, prompt)` to QuickActionsService using proven osascript pattern
- CreateProjectDialog now passes `wantsNotion` and `displayName` in pop result map
- ResearchTab post-creation flow: Notion action takes priority, opening Claude Code in Terminal with the German Notion prompt
- Existing Terminal/rem-sleep fallbacks unchanged when Notion toggle is off

## Task Commits

Each task was committed atomically:

1. **Task 1: Add openClaudeWithPrompt + pass wantsNotion/displayName from dialog** - `f36ae03` (feat)
2. **Task 2: Wire Notion action in ResearchTab post-creation flow** - `b7e5c58` (feat)

## Files Created/Modified
- `pro_orc/lib/data/services/quick_actions_service.dart` - Added `openClaudeWithPrompt` method with single-quote shell escaping
- `pro_orc/lib/features/shared/create_project_dialog.dart` - Pop result now includes `wantsNotion` and `displayName`
- `pro_orc/lib/features/research/research_tab.dart` - Notion-priority post-creation action wiring

## Decisions Made
- `wantsNotion` takes priority over Terminal/rem-sleep since Claude Code itself opens in a Terminal window — no separate Terminal action needed
- German prompt: "Erstelle eine Notion-Seite mit dem Titel '[name]' und schreibe die URL als <!-- notion: URL --> in die PROJECT.md Datei..."
- Single-quote shell escaping chosen over double-quote to handle German text that may contain special characters or double quotes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Pre-existing analyze warnings (gsd_parser.dart unnecessary_non_null_assertion, launch_dialog.dart withOpacity, widget_test.dart MyApp) are tracked in STATE.md tech debt and not caused by this plan.

## User Setup Required

None - no external service configuration required. Notion integration runs via Claude's existing MCP connection.

## Next Phase Readiness
- Notion integration complete for research project creation
- Manual test: Create research project with Notion ON -> Terminal opens with Claude running German prompt
- Manual test: Create research project with Notion OFF, Terminal ON -> Terminal opens normally
- Manual test: Create research project with Notion OFF, rem-sleep ON -> rem-sleep runs as before

---
*Phase: 16-notion-via-claude*
*Completed: 2026-02-26*
