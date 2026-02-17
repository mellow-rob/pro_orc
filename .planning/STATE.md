# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 4 in progress — Live Updates server infrastructure complete (Plan 1 of 2)

## Current Position

Phase: 4 of 5 (Live Updates) — IN PROGRESS
Plan: 1 of 2 in current phase
Status: Plan 1 complete — server-side SSE infrastructure ready
Last activity: 2026-02-17 — Completed Phase 4 Plan 1 (watcher, SSE route, per-project endpoint)

Progress: [█████████████████░░░] 85%

## Performance Metrics

**Velocity:**
- Total plans completed: 9
- Average duration: 2.2min
- Total execution time: 0.33 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 8min | 2.7min |
| 02-data-layer | 3 | 8min | 2.7min |
| 03-static-dashboard | 2 | 3min | 1.5min |
| 04-live-updates | 1 | 2min | 2.0min |

**Recent Trend:**
- Last 5 plans: 02-03 (2min), 03-01 (1min), 03-02 (2min), 04-01 (2min)
- Trend: Consistent ~2min per plan

*Updated after each plan completion*

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1 RESOLVED]: serverExternalPackages added to next.config.ts — chokidar, simple-git, fsevents
- [Phase 5]: `~/.claude/` directory structure for MCP servers/plugins needs direct inspection before building tools-reader — config format may vary by installation method

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed Phase 4 Plan 1 — server-side SSE infrastructure (watcher, /api/events, /api/projects/[id])
Resume file: None
