---
phase: 04-live-updates
plan: 02
subsystem: ui
tags: [sse, event-source, react, hooks, live-updates, client-side, nextjs]

# Dependency graph
requires:
  - phase: 04-live-updates
    plan: 01
    provides: /api/events SSE endpoint, /api/projects/[id] per-project endpoint, SseEvent type

provides:
  - hooks/useProjectEvents.ts: EventSource hook with SSE subscription, re-fetch on project:updated, cleanup on unmount
  - Updated projectTabs.tsx: live data Map state merged over server-rendered props, one EventSource per component mount

affects:
  - 05-claude-tools (any future live update consumers can reuse useProjectEvents pattern)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "useCallback with empty deps for stable EventSource callback — prevents hook re-running on every render"
    - "Map<string, Project> live data overlay merged over server-rendered props before filtering"
    - "EventSource cleanup via source.close() in useEffect return — prevents zombie connections"
    - "Signal-only SSE: hook receives type+projectId, re-fetches full project data via /api/projects/[id]"

key-files:
  created:
    - pro-orc/hooks/useProjectEvents.ts
  modified:
    - pro-orc/components/projectTabs.tsx

key-decisions:
  - "useCallback with empty deps wraps the onUpdate handler — referential stability ensures useProjectEvents useEffect does not re-run on every render, preventing duplicate EventSource connections"
  - "liveData Map stored in useState, updated via functional update (new Map(prev).set(...)) to preserve immutability and trigger re-render"
  - "Live data merged before the isPrivate filter so resolved arrays feed all downstream logic including tab counts"

patterns-established:
  - "useProjectEvents pattern: accept stable callback, open EventSource in useEffect, close in cleanup"
  - "Live data overlay: Map<string, T> state, functional Map update, spread over prop arrays before use"

requirements-completed:
  - LIVE-05

# Metrics
duration: 1min
completed: 2026-02-17
---

# Phase 4 Plan 02: Live Updates Client Hook Summary

**EventSource hook (useProjectEvents) wires browser to /api/events SSE stream, re-fetching project data on project:updated signals and merging live state over server-rendered props in ProjectTabs without page reload**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-17T16:00:40Z
- **Completed:** 2026-02-17T16:01:47Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- `hooks/useProjectEvents.ts` — client-side EventSource hook: opens `/api/events` connection in useEffect, parses `SseEvent`, filters for `project:updated`, re-fetches `/api/projects/[id]`, calls `onUpdate` with fresh `Project` data; `source.close()` cleanup prevents zombie connections
- `components/projectTabs.tsx` — live data overlay integrated: `useState<Map<string, Project>>` stores live updates keyed by project id; stable `useCallback` handler (empty deps) prevents EventSource re-creation on re-render; `resolvedCode`/`resolvedResearch` arrays merge live data over server props before filtering and rendering
- End-to-end live update circuit complete: disk change -> chokidar -> debounce -> SSE push -> EventSource -> re-fetch -> card re-render

## Task Commits

Each task was committed atomically:

1. **Task 1: Create useProjectEvents hook and integrate into ProjectTabs** - `1bf8c76` (feat)

## Files Created/Modified
- `pro-orc/hooks/useProjectEvents.ts` - EventSource SSE subscription hook with fetch-on-event and cleanup
- `pro-orc/components/projectTabs.tsx` - Added liveData Map state, useProjectEvents integration, resolved arrays merged before filtering

## Decisions Made
- `useCallback` with empty deps array wraps `handleUpdate` in `ProjectTabs` so the callback reference is stable across renders. This is critical: `useProjectEvents` lists `onUpdate` in its `useEffect` dependency array, so an unstable callback would create a new `EventSource` on every render — creating zombie connections.
- `liveData` uses a functional Map update `new Map(prev).set(...)` to ensure React detects the state change (object identity changes) and triggers a re-render.
- Live data is merged before the `isPrivate` filter and before tab count calculation, so all downstream logic (counts, card rendering, private grouping) reflects live data automatically.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — `npx tsc --noEmit` passed on first run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 4 (Live Updates) is now complete. End-to-end live update circuit operational:
- File change on disk triggers chokidar watcher (Plan 01)
- 300ms debounce fires SSE event via `/api/events` (Plan 01)
- Browser `EventSource` in `useProjectEvents` receives event (Plan 02)
- Hook re-fetches `/api/projects/[id]` and calls `onUpdate` (Plan 02)
- `ProjectTabs` merges fresh project data and React re-renders affected cards (Plan 02)

Ready for Phase 5: Claude Tools integration.

---
*Phase: 04-live-updates*
*Completed: 2026-02-17*

## Self-Check: PASSED

All files present and commits verified:
- pro-orc/hooks/useProjectEvents.ts: FOUND
- pro-orc/components/projectTabs.tsx: FOUND
- 04-02-SUMMARY.md: FOUND
- commit 1bf8c76: FOUND
