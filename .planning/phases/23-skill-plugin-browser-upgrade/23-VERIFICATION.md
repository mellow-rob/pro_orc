---
phase: 23-skill-plugin-browser-upgrade
verified: 2026-03-09T14:30:00Z
status: human_needed
score: 9/9 must-haves verified
human_verification:
  - test: "Navigate to Claude Tools tab, select a project from dropdown that has .claude/skills/ or .mcp.json"
    expected: "Project-specific skills and MCP servers appear with 'Projekt' scope badge, global tools show 'Global' badge"
    why_human: "Visual rendering, dropdown interaction, scope badge positioning"
  - test: "Click 'Im Editor oeffnen' on a Skill card"
    expected: "SKILL.md opens in default editor application"
    why_human: "External process launch, correct file path"
  - test: "Click 'Im Editor oeffnen' on an MCP server card"
    expected: "settings.json opens in default editor"
    why_human: "External process launch"
  - test: "Verify plugin card shows author name and date"
    expected: "'von AuthorName' in italic, 'Aktualisiert: dd.MM.yyyy' or 'Installiert: dd.MM.yyyy'"
    why_human: "Visual rendering, date formatting"
  - test: "Click a plugin card to open detail panel, verify metadata rows"
    expected: "Detail panel shows Autor, Installiert, Aktualisiert rows in INFO section"
    why_human: "Visual rendering in detail panel"
  - test: "Switch back to 'Alle Tools (Global)' in dropdown"
    expected: "Original global-only view restored, no scope badges shown"
    why_human: "State reset behavior"
---

# Phase 23: Skill/Plugin Browser Upgrade Verification Report

**Phase Goal:** User sieht auf einen Blick welche Skills und Plugins pro Projekt aktiv sind und kann sie direkt oeffnen
**Verified:** 2026-03-09T14:30:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PluginData contains author, installedAt, and lastUpdated fields parsed from filesystem | VERIFIED | `claude_tool_model.dart` lines 75-81: `author` (String?), `installedAt` (DateTime?), `lastUpdated` (DateTime?) fields; scanner lines 185-198: parses from plugin.json and installed_plugins.json |
| 2 | Scanner can detect per-project skills from project/.claude/skills/ | VERIFIED | `claude_tools_scanner.dart` lines 351-378: `_scanProjectSkills()` reads project skills dir, returns SkillData with `scope: 'project'` |
| 3 | Scanner can detect per-project MCP servers from project/.mcp.json | VERIFIED | `claude_tools_scanner.dart` lines 385-426: `_scanProjectMcpServers()` reads .mcp.json, returns McpServerData with `scope: 'project'` |
| 4 | Per-project scan gracefully returns empty lists when no project-level config exists | VERIFIED | Tests confirm: `claude_tools_scanner_test.dart` lines 307-315 |
| 5 | User sieht im Claude Tools Tab ein Projekt-Dropdown zur Filterung | VERIFIED | `claude_tools_tab.dart` lines 207, 330-377: `_buildProjectSelector()` builds DropdownButton with projects list and "Alle Tools (Global)" default |
| 6 | Bei Projektauswahl werden projekt-spezifische Skills und MCP-Server angezeigt | VERIFIED | `claude_tools_tab.dart` lines 171-177: watches `projectToolsProvider`, merges global+project via `_mergeSkills()` and `_mergeMcpServers()` |
| 7 | Plugin-Cards zeigen Autor, Installationsdatum und letztes Update | VERIFIED | `plugin_card.dart` lines 87-119: author line "von ${plugin.author}", date line "Aktualisiert:/Installiert:" with `_formatDate()` |
| 8 | User kann per Quick Action jedes Skill/Plugin/MCP-Server-Config im Editor oeffnen | VERIFIED | skill_card.dart lines 84-93: "Im Editor oeffnen" button opens SKILL.md; mcp_server_card.dart lines 148-160: "Im Editor oeffnen" button opens settings.json; detail panels have corresponding ActionChips |
| 9 | Globale Ansicht (Standard) zeigt alle Tools wie bisher | VERIFIED | `selectedProjectPathProvider` defaults to null; `_mergeSkills()` returns global only when projectData is null; scope badges only shown when `selectedPath != null` |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pro_orc/lib/data/models/claude_tool_model.dart` | PluginData with author/date metadata, SkillData/McpServerData with scope | VERIFIED | All fields present: author (line 75), installedAt (line 78), lastUpdated (line 81), scope on SkillData (line 35) and McpServerData (line 123) |
| `pro_orc/lib/data/services/claude_tools_scanner.dart` | scanProjectTools() method, enriched _scanPlugins | VERIFIED | `scanAll()` (line 30), `scanProjectTools()` (line 55) both public. Author/date parsing in `_scanPlugins()` lines 185-198 |
| `pro_orc/test/data/claude_tools_scanner_test.dart` | Unit tests for metadata and per-project scanning | VERIFIED | 370 lines, 16 tests: metadata parsing (6), scope fields (5), per-project scanning (5) |
| `pro_orc/lib/features/claude_tools/claude_tools_tab.dart` | Project dropdown selector, per-project tool filtering | VERIFIED | DropdownButton at line 346, `_mergeSkills()` at line 267, `_wrapWithScopeBadge()` at line 295 |
| `pro_orc/lib/features/claude_tools/plugin_card.dart` | Author and date metadata display | VERIFIED | "von" author line 90, date line 113-118, `_formatDate()` helper at line 10 |
| `pro_orc/lib/features/claude_tools/skill_card.dart` | Open in Editor quick action | VERIFIED | "Im Editor oeffnen" button at line 85 with filePenLine100 icon, opens SKILL.md |
| `pro_orc/lib/features/claude_tools/mcp_server_card.dart` | Open config in Editor quick action | VERIFIED | "Im Editor oeffnen" button at line 148 with filePenLine100 icon |
| `pro_orc/lib/features/shared/claude_tool_detail_panel.dart` | Metadata in plugin detail, Editor actions in all detail panels | VERIFIED | Plugin detail: Autor (line 208), Installiert (line 210), Aktualisiert (line 212); Skill detail: "Im Editor oeffnen" ActionChip (line 149); MCP detail: "Im Editor oeffnen" ActionChip (line 353) |
| `pro_orc/lib/providers/claude_tools_provider.dart` | Project-scoped tool scanning | VERIFIED | `SelectedProjectPathNotifier` (line 9), `selectedProjectPathProvider` (line 16), `projectToolsProvider` (line 38) calling `scanProjectTools()` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| claude_tools_scanner.dart | claude_tool_model.dart | PluginData constructor with author/dates | WIRED | Line 208: `PluginData(... author: author, installedAt: installedAt, lastUpdated: lastUpdated)` |
| claude_tools_scanner_test.dart | claude_tools_scanner.dart | ClaudeToolsScanner with temp dir override | WIRED | Line 125: `ClaudeToolsScanner(claudeDirOverride: claudeDir)`, line 274: same for project scanning |
| claude_tools_tab.dart | claude_tools_provider.dart | ref.watch with project filter | WIRED | Line 49: `ref.watch(claudeToolsProvider)`, line 171: `ref.watch(selectedProjectPathProvider)`, line 172: `ref.watch(projectToolsProvider)` |
| claude_tools_tab.dart | projects_provider.dart | Project list for dropdown | WIRED | Line 331: `ref.watch(projectsProvider)` in `_buildProjectSelector()` |
| plugin_card.dart | claude_tool_model.dart | PluginData.author, installedAt, lastUpdated | WIRED | Lines 87, 90 (`plugin.author`), 111-118 (`plugin.lastUpdated`, `plugin.installedAt`) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SPB-01 | 23-01, 23-02 | User sieht pro Projekt welche Skills und Plugins aktiv/installiert sind | SATISFIED | Project dropdown (claude_tools_tab.dart line 346), per-project scanning (scanner line 55), scope badges (tab line 295), merged display (tab lines 175-177) |
| SPB-02 | 23-02 | User kann per Quick Action ein Skill/Plugin im Editor oeffnen oder Docs anzeigen | SATISFIED | Skill card: "Im Editor oeffnen" (skill_card.dart line 85), MCP card: "Im Editor oeffnen" (mcp_server_card.dart line 148), detail panels: ActionChips (claude_tool_detail_panel.dart lines 149, 353) |
| SPB-03 | 23-01, 23-02 | Browser zeigt Metadaten (Autor, installiert am, zuletzt aktualisiert) pro Plugin | SATISFIED | Model fields (claude_tool_model.dart lines 75-81), scanner parsing (claude_tools_scanner.dart lines 185-198), card display (plugin_card.dart lines 87-118), detail panel rows (claude_tool_detail_panel.dart lines 207-212) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| mcp_server_card.dart | 148-160 | "Im Editor oeffnen" opens same file as "settings.json oeffnen" (both open settings.json) | Info | Functionally redundant but acceptable per plan spec -- provides "edit" affordance |

### Human Verification Required

### 1. Project Dropdown and Scope Badges

**Test:** Navigate to Claude Tools tab, select a project from dropdown that has `.claude/skills/` or `.mcp.json`
**Expected:** Project-specific skills and MCP servers appear with "Projekt" scope badge, global tools show "Global" badge
**Why human:** Visual rendering, dropdown interaction, scope badge positioning via Stack overlay

### 2. Skill Card Editor Action

**Test:** Click "Im Editor oeffnen" on a Skill card
**Expected:** SKILL.md opens in default editor application
**Why human:** External process launch, correct file path resolution

### 3. MCP Server Card Editor Action

**Test:** Click "Im Editor oeffnen" on an MCP server card
**Expected:** settings.json opens in default editor
**Why human:** External process launch

### 4. Plugin Card Metadata Display

**Test:** Verify plugin card shows author name and date
**Expected:** "von AuthorName" in italic, "Aktualisiert: dd.MM.yyyy" or "Installiert: dd.MM.yyyy"
**Why human:** Visual rendering, date formatting correctness

### 5. Plugin Detail Panel Metadata

**Test:** Click a plugin card to open detail panel, verify metadata rows
**Expected:** Detail panel shows Autor, Installiert, Aktualisiert rows in INFO section
**Why human:** Visual rendering in modal detail panel

### 6. Global View Restore

**Test:** Switch back to "Alle Tools (Global)" in dropdown
**Expected:** Original global-only view restored, no scope badges shown
**Why human:** State reset and re-render behavior

### Gaps Summary

No gaps found. All 9 must-have truths from both plans are verified in the codebase. All three requirement IDs (SPB-01, SPB-02, SPB-03) are satisfied. The data layer has enriched models with metadata fields and per-project scanning capability, and the UI layer integrates these with a project dropdown, metadata display, and editor quick actions. 16 unit tests cover the data layer. No anti-pattern blockers found. Human verification is needed for visual rendering and external process launches.

---

_Verified: 2026-03-09T14:30:00Z_
_Verifier: Claude (gsd-verifier)_
