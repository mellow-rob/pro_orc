---
phase: 23-skill-plugin-browser-upgrade
plan: 02
subsystem: ui-layer
tags: [project-selector, metadata-display, quick-actions, claude-tools-tab]
dependency_graph:
  requires: [enriched-plugin-model, per-project-scanning]
  provides: [project-filtered-tools-ui, plugin-metadata-cards, editor-quick-actions]
  affects: [claude-tools-tab, plugin-card, skill-card, mcp-server-card, detail-panels]
tech_stack:
  added: []
  patterns: [notifier-provider-for-state, scope-badge-overlay, merged-global-project-lists]
key_files:
  created: []
  modified:
    - pro_orc/lib/providers/claude_tools_provider.dart
    - pro_orc/lib/features/claude_tools/claude_tools_tab.dart
    - pro_orc/lib/features/claude_tools/plugin_card.dart
    - pro_orc/lib/features/claude_tools/skill_card.dart
    - pro_orc/lib/features/claude_tools/mcp_server_card.dart
    - pro_orc/lib/features/shared/claude_tool_detail_panel.dart
decisions:
  - SelectedProjectPathNotifier (NotifierProvider) not StateProvider — Riverpod 3.x API
  - Scope badges via Stack overlay on cards — non-invasive, no card API changes needed
  - filePenLine100 icon for editor actions — fileEdit not available in lucide_icons_flutter 3.x
metrics:
  duration: ~19m
  completed: "2026-03-09T14:10:00Z"
  tasks: 2 of 3 (Task 3 = human-verify checkpoint)
  tests_added: 0
  files_changed: 6
---

# Phase 23 Plan 02: UI Layer - Project Selector, Metadata Display, Quick Actions Summary

Project dropdown in Claude Tools tab filters tools by project, plugin cards show author/date metadata, all tool types have "Im Editor oeffnen" quick actions on cards and detail panels.

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Add project selector + per-project scanning | a9760c8 | claude_tools_provider.dart, claude_tools_tab.dart |
| 2 | Plugin metadata + Im Editor oeffnen quick actions | 1f30a80 | plugin_card.dart, skill_card.dart, mcp_server_card.dart, claude_tool_detail_panel.dart |

## Key Changes

### Provider Layer (claude_tools_provider.dart)
- New `SelectedProjectPathNotifier` + `selectedProjectPathProvider` for project selection state
- New `projectToolsProvider` (FutureProvider) that calls `scanProjectTools()` when project selected
- Existing `claudeToolsProvider` unchanged (always global)

### Claude Tools Tab (claude_tools_tab.dart)
- Project dropdown between search field and sections
- Default "Alle Tools (Global)" shows existing behavior
- When project selected: merges global + project tools, shows scope badges (Projekt/Global)
- Scope badges as Stack overlay on cards — cyan for Projekt, dim for Global

### Plugin Card (plugin_card.dart)
- Author line: "von {author}" in italic dim text
- Date line: "Aktualisiert: dd.MM.yyyy" or "Installiert: dd.MM.yyyy"
- Manual date formatting via padLeft (no intl dependency)

### Skill Card + MCP Server Card
- New "Im Editor oeffnen" button (filePenLine100 icon) on both cards
- Skill: opens SKILL.md, MCP: opens settings.json

### Detail Panels (claude_tool_detail_panel.dart)
- Plugin detail: Autor, Installiert, Aktualisiert info rows in INFO section
- Skill detail: "Im Editor oeffnen" action chip
- MCP server detail: "Im Editor oeffnen" action chip

## Verification

- `flutter analyze`: No issues found
- `flutter test`: 122/122 passed
- Task 3 (visual verification) pending as checkpoint

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] StateProvider not available in Riverpod 3.x**
- **Found during:** Task 1
- **Issue:** Plan specified `StateProvider<String?>` but Riverpod 3.x removed StateProvider
- **Fix:** Used `NotifierProvider` with `SelectedProjectPathNotifier` class instead
- **Files modified:** claude_tools_provider.dart

**2. [Rule 1 - Bug] LucideIcons.fileEdit does not exist**
- **Found during:** Task 2
- **Issue:** Plan specified `LucideIcons.fileEdit` but icon not in lucide_icons_flutter 3.x
- **Fix:** Used `LucideIcons.filePenLine100` instead (closest match with 100 weight suffix)
- **Files modified:** skill_card.dart, mcp_server_card.dart

**3. [Rule 1 - Bug] AsyncValue.valueOrNull not available**
- **Found during:** Task 1
- **Issue:** Used `.valueOrNull` on AsyncValue but getter doesn't exist in this Riverpod version
- **Fix:** Used `.value` instead (returns null when loading/error)
- **Files modified:** claude_tools_tab.dart

## Self-Check: PASSED
