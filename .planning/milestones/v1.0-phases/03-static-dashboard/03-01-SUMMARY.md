---
phase: 03-static-dashboard
plan: 01
subsystem: ui
tags: [react, server-actions, child_process, shadcn, lucide-react, glassmorphism]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "shadcn components (Card, Badge, Button, Progress), CSS variables, glow utilities, TypeScript types"
  - phase: 02-data-layer
    provides: "CodeProject/ResearchProject types, type guards, scanProjects()"
provides:
  - "Server Actions: openInTerminal, openInFinder, openNotionPage"
  - "StatusBadge component with color-coded GSD status styling"
  - "CodeProjectCard with all data fields, stale detection, and quick actions"
  - "ResearchProjectCard with name, status, Notion link (no git data)"
  - "formatRelativeTime and isStale helper functions"
affects: [03-02, 04-live-updates]

# Tech tracking
tech-stack:
  added: []
  patterns: [server-actions-exec, startTransition-action-calls, stale-detection-30d, intl-relative-time]

key-files:
  created:
    - pro-orc/app/actions.ts
    - pro-orc/components/statusBadge.tsx
    - pro-orc/components/codeProjectCard.tsx
    - pro-orc/components/researchProjectCard.tsx
  modified: []

key-decisions:
  - "Notion link uses <a href> not server action for simplicity (per research recommendation)"
  - "isStale and formatRelativeTime are local helpers in codeProjectCard (not shared lib)"
  - "StatusBadge is a shared component in components/statusBadge.tsx (avoids duplication)"

patterns-established:
  - "Server Actions for macOS system commands: validate path, escape quotes, promisify(exec)"
  - "Client card components call server actions via useTransition/startTransition"
  - "Status styling via lookup object with fallback for unknown statuses"

requirements-completed: [DASH-02, DASH-03, DASH-04, DASH-05, DASH-07, DASH-08, ACT-01, ACT-02, ACT-03, ACT-04, RSRCH-01, RSRCH-02, RSRCH-03]

# Metrics
duration: 1min
completed: 2026-02-17
---

# Phase 3 Plan 1: Dashboard Cards Summary

**Server actions for macOS open commands, StatusBadge, CodeProjectCard with stale detection and Terminal/Finder actions, ResearchProjectCard with Notion link**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-17T13:08:26Z
- **Completed:** 2026-02-17T13:09:52Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments
- Server actions for opening Terminal, Finder, and Notion URLs with path validation and shell escaping
- StatusBadge component mapping all known GSD statuses to color-coded outline badges
- CodeProjectCard rendering all dashboard fields (name, status, phase, progress, next step, git timestamp) with 30-day stale detection and quick actions via startTransition
- ResearchProjectCard rendering name, status, next step, and Notion link with no git data (per RSRCH-03)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create server actions and shared StatusBadge component** - `57d9a5c` (feat)
2. **Task 2: Create CodeProjectCard and ResearchProjectCard components** - `00db541` (feat)

## Files Created/Modified
- `pro-orc/app/actions.ts` - Server actions: openInTerminal, openInFinder, openNotionPage with path/URL validation
- `pro-orc/components/statusBadge.tsx` - Shared StatusBadge with color map for building/done/paused/research/planning/archived
- `pro-orc/components/codeProjectCard.tsx` - Code project card with progress bar, stale badge, relative timestamps, Terminal/Finder buttons
- `pro-orc/components/researchProjectCard.tsx` - Research project card with BookOpen icon, accent border, Notion link via anchor tag

## Decisions Made
- Notion link rendered as `<a href>` instead of server action (simpler, no JS required, per research recommendation)
- isStale and formatRelativeTime kept as local helpers in codeProjectCard rather than shared lib (only used in one component)
- StatusBadge extracted to shared component to avoid duplication across both card types

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All 4 component files ready for Plan 02 to wire into page.tsx
- CodeProjectCard and ResearchProjectCard are client components ready to receive serialized Project props from server page
- Server actions ready to be called from card button clicks

## Self-Check: PASSED

All 5 files found. Both task commits verified.

---
*Phase: 03-static-dashboard*
*Completed: 2026-02-17*
