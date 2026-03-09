---
phase: 23-skill-plugin-browser-upgrade
plan: 01
subsystem: data-layer
tags: [models, scanner, per-project, metadata]
dependency_graph:
  requires: []
  provides: [enriched-plugin-model, per-project-scanning]
  affects: [claude-tools-tab-ui, project-detail-panel]
tech_stack:
  added: []
  patterns: [scope-field-pattern, nullable-metadata-fields]
key_files:
  created:
    - pro_orc/test/data/claude_tools_scanner_test.dart
  modified:
    - pro_orc/lib/data/models/claude_tool_model.dart
    - pro_orc/lib/data/services/claude_tools_scanner.dart
decisions:
  - Scope as string field ('global'/'project') not enum — simpler, extensible
  - Per-project MCP source labeled 'Projekt' (German, consistent with UI language)
  - PluginData metadata fields all nullable — backward compatible, no existing call sites broken
metrics:
  duration: 4m 32s
  completed: "2026-03-09T13:27:22Z"
  tasks: 2
  tests_added: 16
  files_changed: 3
---

# Phase 23 Plan 01: Data Layer Enrichment Summary

Enriched PluginData with author/installedAt/lastUpdated metadata fields and added per-project scanning for skills and MCP servers via new scanProjectTools() method.

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Enrich PluginData model + scope fields | 2be1092 | claude_tool_model.dart, claude_tools_scanner.dart, claude_tools_scanner_test.dart |
| 2 | Add per-project scanning | 75bb46c | claude_tools_scanner.dart, claude_tools_scanner_test.dart |

## Key Changes

### Model Enrichment (claude_tool_model.dart)
- **PluginData**: 3 new nullable fields: `author` (String?), `installedAt` (DateTime?), `lastUpdated` (DateTime?)
- **SkillData**: new `scope` field (String, default 'global')
- **McpServerData**: new `scope` field (String, default 'global')
- All changes are backward-compatible (nullable/defaulted)

### Scanner Enhancement (claude_tools_scanner.dart)
- `_scanPlugins()` now parses `author` from plugin.json `author.name` and dates from installed_plugins.json
- New public `scanProjectTools(String projectPath)` method
- New private `_scanProjectSkills()` — reads `<project>/.claude/skills/`
- New private `_scanProjectMcpServers()` — reads `<project>/.mcp.json`
- Both return items with `scope: 'project'`

### Test Coverage (claude_tools_scanner_test.dart)
- 16 tests total: 6 metadata parsing, 5 scope fields, 5 per-project scanning
- Uses real temp directories (no mocking), consistent with project patterns

## Verification

- `flutter test test/data/claude_tools_scanner_test.dart`: 16/16 passed
- `flutter test`: 120/120 passed (up from 104)
- `flutter analyze`: No issues found

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED
