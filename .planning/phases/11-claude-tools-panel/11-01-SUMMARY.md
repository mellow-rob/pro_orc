---
phase: 11-claude-tools-panel
plan: "01"
subsystem: data
tags: [dart, models, scanner, file-io, yaml, json, theme, colors]

# Dependency graph
requires:
  - phase: 09-theme-ui-shell
    provides: AppColors ThemeExtension pattern with existing cyan/fuchsia families
  - phase: 07-data-layer-tdd
    provides: ProjectScanner pure-Dart service pattern (mirrored for ClaudeToolsScanner)
provides:
  - ClaudeToolsData aggregate model (skills, plugins, mcpServers, hasError)
  - SkillData model (id, name, description, homepage, path)
  - PluginData model (key, name, marketplace, version, enabled, description, marketplaceUrl)
  - McpServerData model (name, command, type) + McpServerType enum
  - ClaudeToolsScanner.scanAll() — pure Dart discovery of ~/.claude/
  - AppColors amber/emerald/violet accent token families (Hi/mid/Lo each)
affects:
  - 11-02 (claude_tools_watcher_provider + claude_tools_provider use ClaudeToolsData)
  - 11-03 (ClaudeToolsTab + card widgets use models and new AppColors tokens)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure Dart scanner service with injectable directory override for testability
    - Hand-rolled YAML frontmatter parser (split at first colon, strip quotes)
    - Three-level plugin metadata chain: installed_plugins.json + settings.json + plugin.json
    - Try/catch on every File.readAsString — never throws, returns empty on error

key-files:
  created:
    - pro_orc/lib/data/models/claude_tool_model.dart
    - pro_orc/lib/data/services/claude_tools_scanner.dart
  modified:
    - pro_orc/lib/theme/n3_colors.dart

key-decisions:
  - "ClaudeToolsScanner uses claudeDirOverride constructor param (not static field) — enables temp-dir injection in tests without subclassing"
  - "Skills without SKILL.md/skill.md use folder name as display name, no description — most forgiving fallback, no skills silently dropped"
  - "Amber for Skills (warm/knowledge), Emerald for Plugins (green/active), Violet for MCP (purple/infrastructure) — visually distinct from existing cyan/fuchsia"
  - "AppColors constructor uses required params for all 9 new tokens — compile-time guarantee all instances provide all tokens"

patterns-established:
  - "ClaudeToolsScanner mirrors ProjectScanner: pure Dart, three private scan methods, top-level try/catch, typed result model"
  - "All scanner file I/O is async with individual try/catch — partial failure returns what was found, not an error"
  - "AppColors token families follow Hi/mid/Lo naming (not Hi/mid/Lo/Orb — no orb needed for tool accents)"

requirements-completed: [TOOL-01, TOOL-02, TOOL-03, TOOL-04]

# Metrics
duration: 3min
completed: 2026-02-23
---

# Phase 11 Plan 01: Claude Tools Data Layer Summary

**Pure Dart ClaudeToolsScanner discovers Skills (YAML frontmatter), Plugins (JSON chain), and MCP servers (settings.json) from ~/.claude/, with amber/emerald/violet accent tokens added to AppColors**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-23T08:50:37Z
- **Completed:** 2026-02-23T08:53:42Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- ClaudeToolsData model hierarchy: SkillData, PluginData, McpServerData, McpServerType enum, ClaudeToolsData aggregate — all pure Dart, const constructors
- ClaudeToolsScanner.scanAll() with three private scan methods: SKILL.md YAML frontmatter parsing for skills, installed_plugins.json + settings.json + plugin.json chain for plugins, settings.json mcpServers for MCP servers
- Hand-rolled frontmatter parser handles quoted values with colons (splits only at first colon index)
- AppColors extended from 16 to 25 tokens: amberHi/amber/amberLo, emeraldHi/emerald/emeraldLo, violetHi/violet/violetLo — constructor, fields, dark instance, copyWith(), lerp() all updated

## Task Commits

Each task was committed atomically:

1. **Task 1: Data models + scanner service** - `a3cdcd3` (feat)
2. **Task 2: Extend AppColors with amber, emerald, violet token families** - `52d03bc` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `pro_orc/lib/data/models/claude_tool_model.dart` - SkillData, PluginData, McpServerData, McpServerType, ClaudeToolsData models
- `pro_orc/lib/data/services/claude_tools_scanner.dart` - Pure Dart scanner with three scan methods + YAML frontmatter parser
- `pro_orc/lib/theme/n3_colors.dart` - Extended with 9 new accent color tokens across amber/emerald/violet families

## Decisions Made
- ClaudeToolsScanner uses `claudeDirOverride` constructor param rather than a static field — matches injectable pattern from ProjectScanner, enables temp-dir testing without subclassing
- Skills without any SKILL.md file use the folder name as display name and null description — forgiving fallback ensures no skills are silently dropped from the UI
- Amber (Skills) / Emerald (Plugins) / Violet (MCP) color assignment — warm/knowledge, green/active, purple/infrastructure semantics; all visually distinct from existing cyan/fuchsia

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed dangling library doc comment from model file**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** Triple-slash `///` comment at file top without `library` directive triggers `dangling_library_doc_comments` analyzer warning
- **Fix:** Converted `///` comments to `//` block comments at file top
- **Files modified:** pro_orc/lib/data/models/claude_tool_model.dart
- **Verification:** flutter analyze reports "No issues found"
- **Committed in:** a3cdcd3 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - analyzer compliance)
**Impact on plan:** Trivial style fix, no behavioral change.

## Issues Encountered
- 19 pre-existing test failures confirmed unchanged before and after — all in widget_test.dart, git_reader_test.dart, and watcher_service_test.dart; unrelated to this plan's changes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Data models and scanner service fully ready for Plan 02 (provider layer)
- ClaudeToolsScanner can be instantiated with `claudeDirOverride` for testing
- AppColors has all three accent families ready for Plan 03 (card widgets)
- No blockers

---
*Phase: 11-claude-tools-panel*
*Completed: 2026-02-23*
