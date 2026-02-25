---
phase: 14-add-card-dialog
plan: 01
subsystem: ui
tags: [flutter, glassmorphism, animation, hover, ghost-card, grid]

# Dependency graph
requires:
  - phase: 10-card-widgets
    provides: CodeProjectCard, ResearchProjectCard, GlassCard patterns used as reference
provides:
  - AddProjectCard ghost GlassCard widget with hover animation
  - Code tab grid with AddProjectCard as last item (cyan accent)
  - Research tab grid with AddProjectCard as last item (fuchsia accent)
  - _openCreateDialog placeholder stub ready for 14-02
affects: [14-02-create-dialog]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Ghost card: ClipRRect+BackdropFilter replication with reduced alpha (0.30) instead of wrapping GlassCard"
    - "AnimatedScale + AnimatedContainer for smooth hover transitions (200ms)"
    - "Grid +1 pattern: itemCount: visible.length + 1 with index check for trailing card"
    - "SliverGrid append: extra SliverPadding with childCount:1 after hidden section in CustomScrollView"

key-files:
  created:
    - pro_orc/lib/features/shared/add_project_card.dart
  modified:
    - pro_orc/lib/features/code/code_tab.dart
    - pro_orc/lib/features/research/research_tab.dart

key-decisions:
  - "Ghost card replicates GlassCard internals (ClipRRect+BackdropFilter+Container) instead of wrapping GlassCard widget — required to control bg alpha independently"
  - "AddProjectCard only shown when visible.isNotEmpty || hidden.isNotEmpty — empty state widget unchanged"
  - "In hidden-expanded CustomScrollView, AddProjectCard gets its own third SliverGrid for correct positioning after hidden section"

patterns-established:
  - "Grid trailing card: itemCount+1 with index boundary check in itemBuilder"
  - "Hover animation: MouseRegion + setState(_isHovered) + AnimatedContainer + AnimatedScale combo"

requirements-completed: [ADD-01, ADD-02]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 14 Plan 01: AddProjectCard Summary

**Ghost GlassCard widget with 0.30→0.55 opacity hover, scale, and accent glow, integrated as final grid item in Code (cyan) and Research (fuchsia) tabs**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T08:27:16Z
- **Completed:** 2026-02-25T08:29:16Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- AddProjectCard StatefulWidget with ghost glassmorphism style (alpha 0.30 rest, 0.55 hover)
- MouseRegion hover tracking triggers AnimatedScale (1.02) + AnimatedContainer alpha transition + BoxShadow glow in accentColor
- Code tab grid appends cyan AddProjectCard as final item, both in simple GridView and hidden-expanded CustomScrollView
- Research tab grid appends fuchsia AddProjectCard as final item with same dual-path logic
- Empty state preserved — card only shown when at least one project exists (visible or hidden)

## Task Commits

Each task was committed atomically:

1. **Task 1: AddProjectCard Widget** - `197e1eb` (feat)
2. **Task 2: Integrate AddProjectCard into Code and Research tabs** - `38206a6` (feat)

## Files Created/Modified

- `pro_orc/lib/features/shared/add_project_card.dart` - Ghost GlassCard widget with hover animation, accentColor + onTap params
- `pro_orc/lib/features/code/code_tab.dart` - Import + grid integration (itemCount+1 and SliverGrid append) + placeholder _openCreateDialog
- `pro_orc/lib/features/research/research_tab.dart` - Same as Code tab but fuchsia accent

## Decisions Made

- Replicated GlassCard internals rather than wrapping it — GlassCard hardcodes alpha 0.55, ghost needs 0.30 at rest. Direct ClipRRect+BackdropFilter+Container pattern was the clean solution.
- Used AnimatedScale widget (simpler than Transform.scale inside AnimatedContainer) for the scale animation.
- In the hidden-expanded CustomScrollView path, appended a third SliverGrid with childCount:1 rather than incrementing the hidden grid's childCount — keeps positioning clean and after the hidden section.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- AddProjectCard is visually complete and integrated in both grids
- `_openCreateDialog(context, initialTab)` stub exists in both tabs, ready to be wired to CreateProjectDialog in plan 14-02
- `flutter analyze` confirms zero issues on all new/modified files

---
*Phase: 14-add-card-dialog*
*Completed: 2026-02-25*
