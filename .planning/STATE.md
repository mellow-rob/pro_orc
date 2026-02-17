# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 2 Data Layer complete — scanner, parser, git reader all done

## Current Position

Phase: 2 of 5 (Data Layer) -- COMPLETE
Plan: 3 of 3 in current phase
Status: Phase complete
Last activity: 2026-02-17 — Completed 02-03 scanner module (phase 2 done)

Progress: [████████████░░░░░░░░] 60%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 2.7min
- Total execution time: 0.27 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 8min | 2.7min |
| 02-data-layer | 3 | 8min | 2.7min |

**Recent Trend:**
- Last 5 plans: 01-02 (3min), 01-03 (3min), 02-02 (3min), 02-01 (3min), 02-03 (2min)
- Trend: Consistent

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1 RESOLVED]: serverExternalPackages added to next.config.ts — chokidar, simple-git, fsevents
- [Phase 5]: `~/.claude/` directory structure for MCP servers/plugins needs direct inspection before building tools-reader — config format may vary by installation method

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 02-03-PLAN.md (Phase 2 complete)
Resume file: None
