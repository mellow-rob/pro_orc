---
phase: 11-claude-tools-panel
plan: "02"
subsystem: providers+ui
tags: [riverpod, flutter, ui, file-watcher, cards, search]

# Dependency graph
requires:
  - phase: 11-claude-tools-panel
    plan: "01"
    provides: ClaudeToolsData, SkillData, PluginData, McpServerData, ClaudeToolsScanner, AppColors amber/emerald/violet tokens
  - phase: 08-reactive-state
    provides: watcherProvider + projectsProvider watcher-invalidation pattern (mirrored exactly)
  - phase: 09-theme-ui-shell
    provides: GlassCard, AppColors ThemeExtension pattern
provides:
  - claudeToolsWatcherProvider (StreamProvider watching ~/.claude/ with keepAlive)
  - claudeToolsProvider (FutureProvider with watcher invalidation → ClaudeToolsScanner().scanAll())
  - ClaudeToolsTab (full tab with search, three sections, empty states)
  - SkillCard (amber accent mini GlassCard)
  - PluginCard (emerald accent mini GlassCard)
  - McpServerCard (violet accent mini GlassCard)
affects:
  - 11-03 (if needed — plan 02 may be final plan for Claude Tools feature)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - StreamProvider + keepAlive for long-lived watcher (mirrors watcherProvider)
    - FutureProvider + ref.listen invalidation for data driven by watcher events (mirrors projectsProvider)
    - ConsumerStatefulWidget for tab needing TextEditingController lifecycle
    - Wrap widget for responsive mini card grid (spacing: 12, runSpacing: 12)
    - All three sections always visible regardless of search filter (locked decision)

key-files:
  created:
    - pro_orc/lib/providers/claude_tools_watcher_provider.dart
    - pro_orc/lib/providers/claude_tools_provider.dart
    - pro_orc/lib/features/claude_tools/skill_card.dart
    - pro_orc/lib/features/claude_tools/plugin_card.dart
    - pro_orc/lib/features/claude_tools/mcp_server_card.dart
  modified:
    - pro_orc/lib/features/claude_tools/claude_tools_tab.dart

key-decisions:
  - "claudeToolsWatcherProvider mirrors watcherProvider exactly — same keepAlive, same WatcherService, same yield* events pattern"
  - "claudeToolsProvider mirrors projectsProvider exactly — ref.listen hasValue check before invalidateSelf()"
  - "ClaudeToolsTab is ConsumerStatefulWidget — TextEditingController requires initState/dispose lifecycle"
  - "Wrap widget chosen over GridView for mini cards — natural flow layout, no fixed height constraint needed for small cards"
  - "Full empty state only shown when data.isEmpty AND searchQuery is empty — search on empty data still shows sections"
  - "_ActionButton private class factored out per card file (not shared) — three card files stay self-contained"

patterns-established:
  - "Per-card private _ActionButton class — compact icon button (28x28, iconSize 16) for action rows"
  - "Type badge pattern (Container + BoxDecoration + borderRadius 4) — reused in PluginCard and McpServerCard"
  - "Section header: Icon + Text + count in parentheses — visual hierarchy without heavy headers"

requirements-completed: [TOOL-01, TOOL-02, TOOL-03, TOOL-04]

# Metrics
duration: 2min
completed: 2026-02-23
---

# Phase 11 Plan 02: Provider Layer + UI Summary

**Riverpod watcher/provider chain and full Claude Tools tab UI — Skills/Plugins/MCP-Server in three sections with amber/emerald/violet mini GlassCards, live search, and file-watcher-driven re-scan**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-23T09:03:55Z
- **Completed:** 2026-02-23T09:06:12Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- `claudeToolsWatcherProvider`: StreamProvider watching `~/.claude/` with `ref.keepAlive()` — exact mirror of `watcherProvider`
- `claudeToolsProvider`: FutureProvider calling `ClaudeToolsScanner().scanAll()` with `ref.listen` invalidation on watcher events — exact mirror of `projectsProvider`
- `ClaudeToolsTab`: Replaces stub entirely. ConsumerStatefulWidget with `TextEditingController`, handles loading/error/data AsyncValue states, full empty state with help text, three-section content layout with search field
- `SkillCard`: 240px amber GlassCard — name, description (or "Keine Beschreibung"), Finder + Homepage actions
- `PluginCard`: 240px emerald GlassCard — name, version badge, Aktiv/Inaktiv status pill, description, Marketplace link
- `McpServerCard`: 240px violet GlassCard — name, STDIO/HTTP/SSE type badge, monospace command/URL, opens `settings.json`
- Search field filters all three sections live by name (case-insensitive); all sections always visible; clear button when active

## Task Commits

Each task was committed atomically:

1. **Task 1: Riverpod providers for Claude Tools** - `bf725a3` (feat)
2. **Task 2: Claude Tools tab + card widgets** - `920af59` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `pro_orc/lib/providers/claude_tools_watcher_provider.dart` — StreamProvider watching ~/.claude/ with keepAlive
- `pro_orc/lib/providers/claude_tools_provider.dart` — FutureProvider with watcher invalidation chain
- `pro_orc/lib/features/claude_tools/claude_tools_tab.dart` — Full tab replacing stub (ConsumerStatefulWidget)
- `pro_orc/lib/features/claude_tools/skill_card.dart` — SkillCard with amber accent
- `pro_orc/lib/features/claude_tools/plugin_card.dart` — PluginCard with emerald accent
- `pro_orc/lib/features/claude_tools/mcp_server_card.dart` — McpServerCard with violet accent

## Decisions Made

- `claudeToolsWatcherProvider` mirrors `watcherProvider` exactly — same `keepAlive`, same `WatcherService`, same `yield* events` pattern
- `claudeToolsProvider` mirrors `projectsProvider` exactly — `ref.listen` with `hasValue` check before `invalidateSelf()`
- `ClaudeToolsTab` is `ConsumerStatefulWidget` — `TextEditingController` requires `initState`/`dispose` lifecycle
- `Wrap` widget chosen over `GridView` for mini cards — natural flow layout, no fixed height constraint needed for compact cards
- Full empty state only shown when `data.isEmpty` AND `searchQuery.isEmpty` — avoids hiding content when user has cleared search
- Private `_ActionButton` class per card file (not a shared widget) — keeps each card file self-contained and avoids premature abstraction

## Deviations from Plan

None — plan executed exactly as written. Both tasks completed with zero analyzer errors in new files. Pre-existing warnings/errors in gsd_parser.dart, settings_tab.dart, launch_dialog.dart, and test files remain unchanged (out of scope per deviation rules).

## Issues Encountered

- 18 pre-existing test failures confirmed unchanged (same set as documented in 11-01 SUMMARY: widget_test.dart, git_reader_test.dart, watcher_service_test.dart). Not caused by this plan's changes.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Claude Tools tab is fully functional; provider chain wires scanner to UI with live updates
- Phase 11 may be complete — all three plans (data models, provider+UI) delivered the full Claude Tools feature
- If 11-03 exists, it would cover additional enhancements (e.g., detail panels, editing)

---
*Phase: 11-claude-tools-panel*
*Completed: 2026-02-23*

## Self-Check: PASSED

- FOUND: pro_orc/lib/providers/claude_tools_watcher_provider.dart
- FOUND: pro_orc/lib/providers/claude_tools_provider.dart
- FOUND: pro_orc/lib/features/claude_tools/claude_tools_tab.dart
- FOUND: pro_orc/lib/features/claude_tools/skill_card.dart
- FOUND: pro_orc/lib/features/claude_tools/plugin_card.dart
- FOUND: pro_orc/lib/features/claude_tools/mcp_server_card.dart
- FOUND: .planning/phases/11-claude-tools-panel/11-02-SUMMARY.md
- FOUND commit: bf725a3 (Task 1 — providers)
- FOUND commit: 920af59 (Task 2 — tab + cards)
