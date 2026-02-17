# Roadmap: Pro Orc — Project Orchestration Dashboard

## Overview

Pro Orc is built in five coherent phases: first laying a correctly-configured foundation (the pitfalls that bite later must be pre-empted on day zero), then building the data layer in isolation so its shapes are validated before any UI touches them, then assembling a fully functional static dashboard that proves core value, then wiring live updates on top of that working base, and finally adding the Claude Tools inventory as a self-contained panel. Each phase delivers a verifiable capability; no phase is a horizontal technical layer.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Next.js project with correct config, Tailwind v4 + shadcn/ui, dark mode CSS, shared types — no feature code until this is right
- [ ] **Phase 2: Data Layer** - Scanner, Parser, and Git Reader modules built and validated in isolation before any UI or API touches them
- [ ] **Phase 3: Static Dashboard** - Fully functional read-only dashboard with both card types, GSD data displayed, and all quick actions — proves core value before SSE complexity
- [ ] **Phase 4: Live Updates** - chokidar singleton + SSE wired on top of the working static dashboard; cards update in real time without page reload
- [ ] **Phase 5: Claude Tools** - Auto-discovered Skills, MCP servers, and Plugins from ~/.claude/ displayed in a dedicated panel

## Phase Details

### Phase 1: Foundation
**Goal**: A correctly-configured Next.js project that pre-empts all known infrastructure pitfalls, with Tailwind v4, shadcn/ui, dark mode CSS variables, and shared TypeScript types in place — so no feature code requires config rewrites later
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, DASH-06
**Success Criteria** (what must be TRUE):
  1. Running `npm run dev` starts the app at localhost:3000 with no network binding
  2. The app renders a dark-background page with correct Tailwind v4 CSS variables applied
  3. `next.config.ts` includes `serverExternalPackages` for chokidar, simple-git, and fsevents
  4. All shared TypeScript types (`ProjectData`, `ResearchProject`, `GsdStatus`, etc.) are defined in `lib/types.ts` and import cleanly
  5. No database, no auth, no hardcoded paths — all resolved via `os.homedir()`
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — Scaffold Next.js project, configure next.config.ts, create lib/types.ts and lib/paths.ts
- [ ] 01-02-PLAN.md — Initialize shadcn/ui New York style, configure n3urala1 dark theme in globals.css
- [ ] 01-03-PLAN.md — Wire root layout with dark class and fonts, create placeholder pages, visual verify

### Phase 2: Data Layer
**Goal**: Scanner, Parser, and Git Reader modules that reliably read the filesystem and git history — tested in isolation so data shapes are validated before any route handler or UI component touches them
**Depends on**: Phase 1
**Requirements**: SCAN-01, SCAN-02, SCAN-03, SCAN-04, SCAN-05, SCAN-06, SCAN-07, SCAN-08, GIT-01, GIT-02, GIT-03, GIT-04, GIT-05
**Success Criteria** (what must be TRUE):
  1. Running the scanner against `~/project_orchestration/code/` and `~/project_orchestration/project research/` returns a list of projects with correct type classification (code vs research)
  2. Parser extracts current phase, next step, phase count, and Notion URL from a real project's `.planning/` files without crashing on malformed or mid-save files
  3. Git reader returns last commit timestamp and message for code projects; non-git directories return no git data (no error)
  4. Concurrent git calls across all projects complete via `Promise.allSettled` within 5 seconds per project
  5. A project missing `.planning/` shows "no GSD data" rather than causing any error
**Plans**: TBD

### Phase 3: Static Dashboard
**Goal**: A fully functional read-only dashboard at localhost:3000 — card grid, both card types, all GSD data visible, all quick actions working — that proves the core value proposition without any live-update complexity
**Depends on**: Phase 2
**Requirements**: DASH-01, DASH-02, DASH-03, DASH-04, DASH-05, DASH-07, DASH-08, ACT-01, ACT-02, ACT-03, ACT-04, RSRCH-01, RSRCH-02, RSRCH-03
**Success Criteria** (what must be TRUE):
  1. Opening localhost:3000 shows a card grid with all auto-discovered projects — code and research displayed in their respective card layouts
  2. Each code project card shows project name, GSD status badge, current phase/total phases, roadmap progress bar, last git activity timestamp, and next step from STATE.md
  3. Projects with no git activity for 30+ days are visually marked as stale
  4. Clicking "Open in Terminal" opens the project folder in Terminal.app; "Open in Finder" opens it in Finder; "Open Notion Page" opens the parsed Notion URL in the browser
  5. Research project cards show name, GSD status, and Notion link — no git metrics displayed
**Plans**: TBD

### Phase 4: Live Updates
**Goal**: The dashboard updates in real time when any `.planning/` file changes — no page reload required — using a chokidar singleton watcher and SSE push
**Depends on**: Phase 3
**Requirements**: LIVE-01, LIVE-02, LIVE-03, LIVE-04, LIVE-05, LIVE-06
**Success Criteria** (what must be TRUE):
  1. Editing a `.planning/STATE.md` file in any project causes the corresponding card to update within ~1 second, without a page reload
  2. The watcher process does not accumulate file descriptors across HMR cycles in dev mode (chokidar singleton lives on `globalThis`)
  3. Closing and reopening the browser tab produces one clean SSE connection, not zombie streams accumulating with each navigation
  4. `node_modules/`, `.git/`, and `.next/` directories are never watched
**Plans**: TBD

### Phase 5: Claude Tools
**Goal**: A dedicated panel showing all auto-discovered Claude capabilities — Skills, MCP servers, and Plugins from `~/.claude/` — so the user can see what tools are available without opening a terminal
**Depends on**: Phase 3
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04
**Success Criteria** (what must be TRUE):
  1. The dashboard includes a Tools panel that lists all installed Claude Skills with name, type, and description
  2. The panel lists configured MCP servers with name, type, and description
  3. The panel lists installed Plugins with name, type, and description
  4. The tools inventory loads by reading `~/.claude/` at startup — no manual configuration required
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/3 | Not started | - |
| 2. Data Layer | 0/TBD | Not started | - |
| 3. Static Dashboard | 0/TBD | Not started | - |
| 4. Live Updates | 0/TBD | Not started | - |
| 5. Claude Tools | 0/TBD | Not started | - |
