---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [nextjs, typescript, chokidar, simple-git, tailwind, tw-animate-css]

# Dependency graph
requires: []
provides:
  - "Next.js 16.1.6 project scaffold at pro-orc/"
  - "serverExternalPackages config for chokidar, simple-git, fsevents"
  - "Shared TypeScript types: Project, CodeProject, ResearchProject discriminated union"
  - "Path constants via os.homedir() in lib/paths.ts"
  - "instrumentation.ts register() placeholder for Phase 4 watcher"
affects: [02-api-layer, 03-ui-components, 04-live-updates, 05-claude-tools]

# Tech tracking
tech-stack:
  added: [next@16.1.6, react@19, typescript@5, tailwindcss@4, chokidar@3.6, simple-git@3, tw-animate-css@1.4]
  patterns: [app-router, turbopack, server-external-packages, discriminated-union-types, os-homedir-paths]

key-files:
  created:
    - pro-orc/next.config.ts
    - pro-orc/instrumentation.ts
    - pro-orc/lib/types.ts
    - pro-orc/lib/paths.ts
  modified: []

key-decisions:
  - "Used create-next-app defaults (TypeScript, Tailwind, ESLint, App Router, Turbopack)"
  - "chokidar pinned to v3 (^3.6.0) per research — v4 ESM-only causes bundling issues"
  - "GsdStatus uses open string union (string & {}) for autocomplete without rigidity"

patterns-established:
  - "serverExternalPackages: all Node-native packages declared upfront in next.config.ts"
  - "os.homedir() paths: all filesystem paths derived from os.homedir(), never hardcoded"
  - "Discriminated union: Project = CodeProject | ResearchProject with type guards"

requirements-completed: [INFRA-01, INFRA-02, INFRA-03, INFRA-04]

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 1 Plan 1: Project Scaffold Summary

**Next.js 16.1.6 scaffold with serverExternalPackages, discriminated union types, and os.homedir() path constants**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T11:40:40Z
- **Completed:** 2026-02-17T11:43:05Z
- **Tasks:** 2
- **Files modified:** 20

## Accomplishments
- Scaffolded Next.js 16.1.6 project with TypeScript, Tailwind CSS 4, App Router, and Turbopack
- Configured serverExternalPackages for chokidar, simple-git, and fsevents to prevent bundling failures
- Created full discriminated union type system (CodeProject | ResearchProject) with type guards
- Created centralized path constants using os.homedir() with zero hardcoded paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold Next.js project and configure next.config.ts** - `870140d` (feat)
2. **Task 2: Create lib/types.ts and lib/paths.ts** - `41bc516` (feat)

## Files Created/Modified
- `pro-orc/next.config.ts` - serverExternalPackages for chokidar, simple-git, fsevents
- `pro-orc/instrumentation.ts` - Empty register() placeholder for Phase 4 watcher bootstrap
- `pro-orc/lib/types.ts` - Discriminated union types: Project, CodeProject, ResearchProject, GsdStatus, ProjectsResponse, SseEvent, type guards
- `pro-orc/lib/paths.ts` - PATHS object (base/code/research/claude), planningDir(), projectIdFromPath()
- `pro-orc/package.json` - Dependencies: chokidar@^3.6.0, simple-git, tw-animate-css

## Decisions Made
- Used create-next-app defaults (TypeScript, Tailwind, ESLint, App Router, Turbopack) -- plan specified --yes flag
- chokidar pinned to v3 (^3.6.0) per research findings -- v4 ESM-only causes bundling friction
- GsdStatus uses open string union pattern `(string & {})` for autocomplete without rigidity

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Project scaffold complete and verified: `npm run dev` starts at localhost:3000 with HTTP 200
- `npx tsc --noEmit` exits clean with all files
- Types and paths ready for Phase 1 Plan 2 (API layer) and Plan 3 (UI components)
- instrumentation.ts ready for Phase 4 watcher integration

## Self-Check: PASSED

All 5 files verified present. Both task commits (870140d, 41bc516) verified in git log.

---
*Phase: 01-foundation*
*Completed: 2026-02-17*
