---
phase: 05-claude-tools
plan: 01
subsystem: api
tags: [tools-scanner, fs.promises, server-only, typescript, claude-tools]

# Dependency graph
requires: []
provides:
  - ClaudeTool interface in lib/types.ts
  - ClaudeToolsData type in lib/types.ts
  - scanClaudeTools() function in lib/tools-scanner.ts
  - Skill scanning from ~/.claude/skills/ with symlink resolution
  - Plugin scanning from installed_plugins.json with MCP detection via .mcp.json
affects:
  - 05-02 (tools panel UI — consumes ClaudeToolsData from scanClaudeTools)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Manual YAML frontmatter parsing via regex (no js-yaml) for skill.md name/description fields"
    - "fs.realpath() for symlink resolution before reading skill.md"
    - "fs.access().then(()=>true).catch(()=>false) for MCP detection"
    - "Try-both pattern for case-insensitive filename: ['skill.md', 'SKILL.md']"
    - "server-only + fs.promises pattern from scanner.ts extended to tools-scanner.ts"

key-files:
  created:
    - pro-orc/lib/tools-scanner.ts
  modified:
    - pro-orc/lib/types.ts

key-decisions:
  - "Manual regex parsing for YAML frontmatter instead of js-yaml — plan specifies no new dependencies"
  - "Dirent[] typed import from 'fs' to resolve TypeScript NonSharedBuffer type inference issue"
  - "skills, mcpPlugins, skillPlugins split into separate arrays in ClaudeToolsData for clean UI separation"

patterns-established:
  - "Pattern: tools-scanner.ts follows scanner.ts exactly (server-only, fs.promises, Promise.all, null-safe try/catch)"
  - "Pattern: Plugin scanning reads installed_plugins.json then checks .mcp.json per installPath for MCP classification"

requirements-completed:
  - TOOL-01
  - TOOL-02
  - TOOL-03

# Metrics
duration: 4min
completed: 2026-02-17
---

# Phase 5 Plan 01: Claude Tools Scanner Summary

**ClaudeTool type + scanClaudeTools() scanning skills via skill.md frontmatter, plugins via installed_plugins.json, MCP detection via .mcp.json presence**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-17T00:00:00Z
- **Completed:** 2026-02-17
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added ClaudeTool interface and ClaudeToolsData type to lib/types.ts with full field documentation
- Created lib/tools-scanner.ts following server-only + fs.promises pattern from scanner.ts
- Implemented symlink-safe skill scanning with try-both case sensitivity (skill.md + SKILL.md)
- Plugin scanning reads installed_plugins.json, extracts .claude-plugin/plugin.json metadata, classifies MCP via .mcp.json detection
- All file reads null-safe with try/catch returning empty arrays or empty objects on error

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ClaudeTool and ClaudeToolsData types to lib/types.ts** - `473ac92` (feat)
2. **Task 2: Create lib/tools-scanner.ts with scanClaudeTools()** - `72f7f42` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `pro-orc/lib/types.ts` - Appended ClaudeTool and ClaudeToolsData interfaces
- `pro-orc/lib/tools-scanner.ts` - New module with scanClaudeTools(), scanSkills(), scanPlugins(), readSettings(), readSkillMd(), parseFrontmatter()

## Decisions Made
- Manual regex parsing for YAML frontmatter instead of js-yaml — plan explicitly requires no new dependencies; simple name/description fields don't need full YAML parser
- Used `import { Dirent } from 'fs'` to resolve TypeScript NonSharedBuffer type inference issue when typing readdir results (Rule 1 auto-fix during Task 2)
- ClaudeToolsData splits plugins into mcpPlugins/skillPlugins arrays at scan time so UI components get pre-classified data

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed TypeScript Dirent type inference error**
- **Found during:** Task 2 (tools-scanner.ts TypeScript verification)
- **Issue:** `Awaited<ReturnType<typeof fs.readdir>>` resolved to `Dirent<NonSharedBuffer>[]` instead of `Dirent[]`, causing type assignment errors throughout the skills scan
- **Fix:** Imported `Dirent` directly from 'fs' and used it as explicit type annotation for the readdir result
- **Files modified:** pro-orc/lib/tools-scanner.ts
- **Verification:** `npx tsc --noEmit` passed with no errors
- **Committed in:** `72f7f42` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — TypeScript type inference)
**Impact on plan:** Auto-fix necessary for correctness. No scope creep.

## Issues Encountered
- TypeScript's `Awaited<ReturnType<typeof fs.readdir>>` with `withFileTypes: true` infers `Dirent<NonSharedBuffer>[]` not `Dirent[]`. Fixed by importing and using `Dirent` type directly from 'fs'.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ClaudeTool and ClaudeToolsData types ready for UI consumption
- scanClaudeTools() ready to be called from app/page.tsx alongside scanProjects()
- Plan 05-02 can immediately add the Tools tab to ProjectTabs and implement ToolsPanel

---
*Phase: 05-claude-tools*
*Completed: 2026-02-17*

## Self-Check: PASSED

- FOUND: pro-orc/lib/tools-scanner.ts
- FOUND: pro-orc/lib/types.ts
- FOUND: 05-01-SUMMARY.md
- FOUND: commit 473ac92 (Task 1)
- FOUND: commit 72f7f42 (Task 2)
