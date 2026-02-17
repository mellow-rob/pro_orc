---
phase: 04-live-updates
plan: 01
subsystem: api
tags: [chokidar, sse, server-sent-events, filesystem-watcher, nextjs, globalThis, singleton]

# Dependency graph
requires:
  - phase: 02-data-layer
    provides: scanner.ts with scanProjects(), git-reader, parser, types, paths
  - phase: 03-static-dashboard
    provides: working Next.js app with API routes pattern established

provides:
  - chokidar v3 singleton on globalThis with HMR guard (lib/watcher.ts)
  - subscriber Set for SSE fan-out (watcherSubscribers export)
  - 300ms per-project debounce via globalThis.__watcherDebounceTimers
  - instrumentation.ts bootstrapping watcher with NEXT_RUNTIME guard
  - /api/events SSE endpoint streaming SseEvent to connected clients
  - /api/projects/[id] endpoint for single-project re-fetch
  - scanProjectById() function in lib/scanner.ts

affects:
  - 04-live-updates (client-side EventSource connection)
  - 05-claude-tools (any feature needing server-side file watching)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "globalThis singleton pattern for Next.js HMR survival"
    - "SSE ReadableStream with abort signal cleanup"
    - "Signal-only SSE events (type + projectId), browser re-fetches data"
    - "instrumentation.ts + NEXT_RUNTIME guard for Node.js-only bootstrap"

key-files:
  created:
    - pro-orc/lib/watcher.ts
    - pro-orc/app/api/events/route.ts
    - pro-orc/app/api/projects/[id]/route.ts
  modified:
    - pro-orc/instrumentation.ts
    - pro-orc/lib/scanner.ts

key-decisions:
  - "globalThis.__watcher guard prevents duplicate chokidar instances on HMR re-execution"
  - "No 'server-only' import in watcher.ts — dynamic import from instrumentation.ts bypasses normal module graph"
  - "watcherSubscribers exported as reference to globalThis.__watcherSubscribers (same Set reference survives HMR)"
  - "SseEvent type from types.ts used for subscriber callbacks — type-safe fan-out"
  - "scanProjectById tries direct path lookup first, then falls back to full scan — avoids unnecessary directory reads"

patterns-established:
  - "globalThis singleton: declare global vars, guard init with if (!globalThis.__x)"
  - "SSE cleanup: request.signal abort → delete subscriber → close controller in try/catch"
  - "Next.js 16 async route params: { params: Promise<{ id: string }> } must be awaited"

requirements-completed:
  - LIVE-01
  - LIVE-02
  - LIVE-03
  - LIVE-04
  - LIVE-06

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 4 Plan 01: Live Updates Server Infrastructure Summary

**Chokidar v3 globalThis singleton with SSE fan-out: watcher.ts debounces filesystem events per-project, /api/events streams SseEvent to connected clients, /api/projects/[id] enables signal-only re-fetch pattern**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-17T15:56:37Z
- **Completed:** 2026-02-17T15:58:16Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- `lib/watcher.ts` — chokidar v3 singleton guarded by `globalThis.__watcher`, survives HMR re-execution; watches `~/project_orchestration/code/` and `~/project_orchestration/project research/`, excludes `node_modules`, `.git`, `.next`; 300ms debounce per projectId; notifies all subscribers with typed `SseEvent`
- `instrumentation.ts` — bootstraps watcher via dynamic import inside `NEXT_RUNTIME === 'nodejs'` guard, ensuring chokidar never loads in Edge runtime
- `app/api/events/route.ts` — SSE endpoint with `ReadableStream`, initial ping event, subscriber registration, abort-signal cleanup
- `app/api/projects/[id]/route.ts` — force-dynamic GET with async params (Next.js 16 pattern), delegates to `scanProjectById`
- `lib/scanner.ts` — `scanProjectById()` exported function: direct path lookup in code/research roots, falls back to full scan, enriches code projects with git data

## Task Commits

Each task was committed atomically:

1. **Task 1: Create watcher singleton and update instrumentation bootstrap** - `8a6b4df` (feat)
2. **Task 2: Create SSE route handler and per-project data endpoint** - `5a72888` (feat)

## Files Created/Modified
- `pro-orc/lib/watcher.ts` - Chokidar v3 globalThis singleton, subscriber Set, per-project debounce, watcherSubscribers export
- `pro-orc/instrumentation.ts` - Server startup bootstrap with NEXT_RUNTIME === 'nodejs' guard
- `pro-orc/app/api/events/route.ts` - SSE endpoint with ReadableStream, initial ping, abort cleanup
- `pro-orc/app/api/projects/[id]/route.ts` - Per-project data endpoint with async params
- `pro-orc/lib/scanner.ts` - Added scanProjectById() with direct lookup + full-scan fallback

## Decisions Made
- No `import 'server-only'` in `watcher.ts` — the file is loaded via dynamic import from `instrumentation.ts`, which runs outside the normal Next.js module graph where `server-only` resolves. Adding it would cause an import error.
- `watcherSubscribers` is exported as `globalThis.__watcherSubscribers!` (a direct reference) rather than wrapping it — both the SSE route and watcher module share the same `Set` object across HMR reloads.
- `scanProjectById` tries direct `path.join(root, id)` first to avoid scanning all projects for a single lookup. Falls back to full `scanDir` only when needed (handles slugified vs raw names).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — `npx tsc --noEmit` passed on first run for both tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Server-side infrastructure complete. Ready for client-side EventSource connection (Phase 4 Plan 02):
- `/api/events` is listening — connect with `new EventSource('/api/events')` in a client component
- `/api/projects/[id]` returns fresh project JSON — use on `project:updated` events to refresh card data
- `watcherSubscribers` Set is populated at server startup, survives HMR — no reconnection issues expected

---
*Phase: 04-live-updates*
*Completed: 2026-02-17*

## Self-Check: PASSED

All files present and commits verified:
- pro-orc/lib/watcher.ts: FOUND
- pro-orc/instrumentation.ts: FOUND
- pro-orc/app/api/events/route.ts: FOUND
- pro-orc/app/api/projects/[id]/route.ts: FOUND
- 04-01-SUMMARY.md: FOUND
- commit 8a6b4df: FOUND
- commit 5a72888: FOUND
