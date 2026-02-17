# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 5 in progress — Claude Tools scanner foundation built

## Current Position

Phase: 5 of 5 (Claude Tools) — IN PROGRESS
Plan: 1 of 2 in current phase
Status: Phase 5 Plan 1 complete — ClaudeTool types and scanClaudeTools() scanner built
Last activity: 2026-02-17 — Completed Phase 5 Plan 1 (ClaudeTool types, tools-scanner.ts with scanClaudeTools)

Progress: [████████████████████] 95%

## Performance Metrics

**Velocity:**
- Total plans completed: 10
- Average duration: 2.1min
- Total execution time: 0.35 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 8min | 2.7min |
| 02-data-layer | 3 | 8min | 2.7min |
| 03-static-dashboard | 2 | 3min | 1.5min |
| 04-live-updates | 2 | 3min | 1.5min |

**Recent Trend:**
- Last 5 plans: 03-01 (1min), 03-02 (2min), 04-01 (2min), 04-02 (1min)
- Trend: Consistent ~1-2min per plan

*Updated after each plan completion*

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 05-claude-tools | 1 | 4min | 4min |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Pre-phase]: Use chokidar v3 (not v4) — ESM-only v4 causes bundling friction with Next.js
- [Pre-phase]: SSE signal-only pattern — events carry `{ type, projectId }`, browser re-fetches `/api/projects/[id]`
- [Pre-phase]: `<!-- notion: URL -->` comment convention in PROJECT.md for Notion URL parsing
- [01-01]: Used create-next-app defaults (TypeScript, Tailwind, ESLint, App Router, Turbopack)
- [01-01]: GsdStatus uses open string union (string & {}) for autocomplete without rigidity
- [01-02]: Cyan = primary (code/actions), Fuchsia = accent (research/highlights)
- [01-02]: Card transparency at oklch 0.18/0.6 opacity for glassmorphism readability
- [01-02]: Kept shadcn/tailwind.css import for component base styles
- [01-03]: Dark class hardcoded on html — no next-themes, no toggle, no flash
- [01-03]: Inter (sans) + JetBrains Mono (mono) fonts via next/font/google CSS variables
- [02-02]: simpleGit constructor inside try-catch — throws synchronously for nonexistent paths
- [02-02]: Vitest with node environment for testing server-only modules
- [02-01]: Added non-bold regex variants (Phase: vs **Phase:**) to handle real STATE.md format
- [02-01]: server-only installed as explicit dependency (not bundled with Next.js 16)
- [03-01]: Notion link uses <a href> not server action (simpler, no JS required)
- [03-01]: StatusBadge shared component avoids duplication across card types
- [03-01]: isStale/formatRelativeTime local to codeProjectCard (single consumer)
- [03-02]: Type-prefixed React keys to avoid collision when same name in code/ and research/
- [03-02]: openNotionPage server action unused — research card uses <a href> instead (dead code, minor)
- [04-01]: No 'server-only' in watcher.ts — dynamic import from instrumentation.ts bypasses normal module graph
- [04-01]: watcherSubscribers exported as reference to globalThis.__watcherSubscribers — same Set reference survives HMR
- [04-01]: scanProjectById tries direct path lookup first before full scan — avoids unnecessary directory reads
- [04-01]: Next.js 16 async route params: { params: Promise<{ id: string }> } must be awaited
- [04-02]: useCallback with empty deps wraps onUpdate handler — referential stability prevents duplicate EventSource connections on re-render
- [04-02]: liveData Map updated via functional update (new Map(prev).set(...)) to preserve immutability and trigger re-render
- [04-02]: Live data merged before isPrivate filter so all downstream logic (counts, rendering, private grouping) reflects live data
- [Phase 05-01]: Manual regex parsing for YAML frontmatter instead of js-yaml — no new dependencies required
- [Phase 05-01]: Dirent type imported from 'fs' to fix TypeScript NonSharedBuffer inference in readdir results
- [Phase 05-01]: ClaudeToolsData splits plugins into mcpPlugins/skillPlugins at scan time for clean UI separation

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1 RESOLVED]: serverExternalPackages added to next.config.ts — chokidar, simple-git, fsevents
- [Phase 5 RESOLVED]: `~/.claude/` directory structure inspected in research — scanner built with direct filesystem knowledge (skills/, plugins/installed_plugins.json, .mcp.json detection)

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 05-01-PLAN.md — ClaudeTool types and scanClaudeTools() scanner module
Resume file: None
