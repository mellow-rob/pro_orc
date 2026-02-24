---
phase: 13-memory-ui-actions
plan: 01
subsystem: ui
tags: [flutter, memory-indicator, lucide-icons, quick-actions, card-widgets]

# Dependency graph
requires:
  - phase: 12-memory-detection
    provides: MemoryData model with hasMemory/lastConsolidated/isStale fields
provides:
  - MemoryIndicator shared widget with 3 visual states (gray/violet/amber)
  - Memory status visible on all Code and Research project cards
  - openRemSleep quick action in QuickActionsService
  - moonStar quick action button on cards with memory data
affects: [claude_tools_tab, project_detail_panel, future card UI changes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - MemoryIndicator follows StatusBadge pattern (StatelessWidget, AppColors param, resolves state internally)
    - Manual date formatting via padLeft instead of intl package (avoids adding dependency)
    - Conditional quick actions with if-guards in actions list (established pattern)

key-files:
  created:
    - pro_orc/lib/features/shared/memory_indicator.dart
  modified:
    - pro_orc/lib/features/code/code_project_card.dart
    - pro_orc/lib/features/research/research_project_card.dart
    - pro_orc/lib/data/services/quick_actions_service.dart

key-decisions:
  - "13-01: No intl dependency — use manual padLeft date formatting for DD.MM.YYYY"
  - "13-01: openRemSleep opens Terminal.app (same as openInTerminal) — simple and consistent, user runs claude manually"

patterns-established:
  - "MemoryIndicator: accepts MemoryData? + AppColors, resolves color/tooltip internally — null-safe, self-contained"
  - "Quick action condition: if (project.memory != null) guards moonStar button — parallel to githubUrl/notionUrl pattern"

requirements-completed: [MUI-01, MUI-02, MUI-03, MACT-01]

# Metrics
duration: 3min
completed: 2026-02-24
---

# Phase 13 Plan 01: Memory UI Actions Summary

**bookMarked memory indicator (3 states: gray/violet/amber) and moonStar rem-sleep quick action added to all Code and Research project cards**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-24T08:49:35Z
- **Completed:** 2026-02-24T08:52:43Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments
- Created MemoryIndicator shared widget: bookMarked100 icon, 3 visual states, German tooltip with date formatting
- Integrated MemoryIndicator into CodeProjectCard title row (between version text and eye icon)
- Integrated MemoryIndicator into ResearchProjectCard title row (between name and eye icon)
- Added openRemSleep method to QuickActionsService (opens Terminal.app at project path)
- Added moonStar100 quick action to both card types, conditional on project.memory != null

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MemoryIndicator widget and integrate into both card types** - `f009d65` (feat)
2. **Task 2: Add openRemSleep quick action to QuickActionsService and both cards** - `1a65bc5` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `pro_orc/lib/features/shared/memory_indicator.dart` - Reusable StatelessWidget, 3 visual states, German tooltips
- `pro_orc/lib/features/code/code_project_card.dart` - MemoryIndicator in title row + moonStar quick action
- `pro_orc/lib/features/research/research_project_card.dart` - MemoryIndicator in title row + moonStar quick action
- `pro_orc/lib/data/services/quick_actions_service.dart` - openRemSleep method added

## Decisions Made
- No `intl` dependency added — used manual `padLeft` date formatting (`DD.MM.YYYY`) to avoid new dependency. Plan explicitly anticipated this fallback.
- `openRemSleep` uses the same `Process.run('open', ['-a', 'Terminal', projectPath])` as `openInTerminal` — simple and consistent, user runs `claude` manually in the opened window.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Pre-existing analyzer warnings in `gsd_parser.dart`, `launch_dialog.dart`, and `widget_test.dart` were present before this plan and are out of scope.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Memory UI complete: indicator and quick action visible on all project cards
- Phase 13 Plan 01 done — ready for Phase 13 Plan 02 (if any) or phase completion

---
*Phase: 13-memory-ui-actions*
*Completed: 2026-02-24*
