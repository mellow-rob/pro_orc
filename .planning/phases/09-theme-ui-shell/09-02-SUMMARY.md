---
phase: 09-theme-ui-shell
plan: 02
subsystem: ui
tags: [flutter, macos, animation, glassmorphism, navigation-rail, custom-painter, riverpod]

# Dependency graph
requires:
  - phase: 09-01
    provides: AppColors ThemeExtension, buildAppTheme factory, GlowBorderShell with no border
provides:
  - OrbBackground: animated atmospheric orb widget (3 orbs, CustomPainter, staggered AnimationControllers)
  - GlassCard: reusable glassmorphism card (BackdropFilter, BlendMode.src, no border)
  - ShellScreen: NavigationRail sidebar + IndexedStack tabs + OrbBackground layered behind scaffold
  - Three placeholder tabs: CodeTab, ResearchTab, ClaudeToolsTab
affects: [09-03, 10-projects-tab, 11-code-tab]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - OrbBackground uses RepaintBoundary + Listenable.merge for efficient animation repaints
    - BackdropFilter with BlendMode.src eliminates white halo artifact on dark backgrounds
    - Orbs placed as Positioned.fill OUTSIDE Scaffold in Stack — bleed behind NavigationRail
    - Scaffold.backgroundColor transparent — orbs visible through all UI layers

key-files:
  created:
    - pro_orc/lib/features/shell/orb_background.dart
    - pro_orc/lib/features/shell/glass_card.dart
    - pro_orc/lib/features/code/code_tab.dart
    - pro_orc/lib/features/research/research_tab.dart
    - pro_orc/lib/features/claude_tools/claude_tools_tab.dart
  modified:
    - pro_orc/lib/features/shell/shell_screen.dart

key-decisions:
  - "OrbBackground is Positioned.fill behind Scaffold in Stack — orbs bleed through NavigationRail and all tabs"
  - "BackdropFilter blendMode: BlendMode.src used to eliminate white halo artifact on dark glassmorphism cards"
  - "No border on GlassCard — locked decision from plan spec, blur effect defines visual separation"
  - "Three AnimationControllers with different durations (18s/23s/28s) create natural desync without explicit phase offsets"
  - "RepaintBoundary wraps CustomPaint — isolates orb animation repaints from parent widget tree"

patterns-established:
  - "Atmospheric orb pattern: Stack with Positioned.fill OrbBackground behind transparent Scaffold"
  - "GlassCard pattern: ClipRRect > BackdropFilter(BlendMode.src) > Container(no border) > child"
  - "Tab pattern: NavigationRail + IndexedStack preserves state across tab switches"

requirements-completed: [UI-04, UI-05]

# Metrics
duration: ~20min
completed: 2026-02-20
---

# Phase 09 Plan 02: Theme + UI Shell — Orbs, Glass, and Navigation Summary

**Animated atmospheric orb background (CustomPainter, 3 staggered controllers), GlassCard with BackdropFilter and BlendMode.src for halo-free glassmorphism, and three-tab NavigationRail shell — human-verified visual identity complete**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-02-20
- **Completed:** 2026-02-20
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 6

## Accomplishments
- OrbBackground renders 3 translucent orbs (2 cyan, 1 fuchsia) drifting slowly with staggered AnimationControllers (18s/23s/28s periods); RepaintBoundary + Listenable.merge drives efficient repaints
- GlassCard uses BackdropFilter with BlendMode.src to eliminate white halo artifact on the dark n3urala1 background; no border, slight translucency reveals orbs through blur
- ShellScreen rebuilt with OrbBackground behind transparent Scaffold in a Stack; NavigationRail sidebar + IndexedStack tabs (Code, Research, Claude Tools); human approved visual result

## Task Commits

Each task was committed atomically:

1. **Task 1: Create OrbBackground and GlassCard widgets** - `baf4447` (feat)
2. **Task 2: Wire tab navigation, orb background, and placeholder tabs into ShellScreen** - `4eb520c` (feat)
3. **Task 3: Visual verification of theme, orbs, glass cards, and tab navigation** - Human approved (checkpoint)

**Plan metadata:** committed with this summary (docs)

## Files Created/Modified
- `pro_orc/lib/features/shell/orb_background.dart` - StatefulWidget with TickerProviderStateMixin, 3 AnimationControllers, _OrbPainter CustomPainter, RepaintBoundary wrapper
- `pro_orc/lib/features/shell/glass_card.dart` - Reusable glassmorphism card: ClipRRect > BackdropFilter(BlendMode.src) > Container, reads AppColors from ThemeExtension
- `pro_orc/lib/features/shell/shell_screen.dart` - Rebuilt build method: Stack(OrbBackground, transparent Scaffold with NavigationRail + IndexedStack)
- `pro_orc/lib/features/code/code_tab.dart` - CodeTab placeholder with centered GlassCard
- `pro_orc/lib/features/research/research_tab.dart` - ResearchTab placeholder with centered GlassCard
- `pro_orc/lib/features/claude_tools/claude_tools_tab.dart` - ClaudeToolsTab placeholder with centered GlassCard

## Decisions Made
- BlendMode.src on BackdropFilter: standard Flutter workaround for white halo on dark backgrounds — no alternative exists without custom shader
- Orbs placed OUTSIDE Scaffold (not inside body): ensures orbs are visually behind NavigationRail, not clipped to the content area
- Different AnimationController durations (not offsets): natural visual desync without explicit phase math; controllers start at 0 but diverge immediately
- IndexedStack over Navigator: preserves tab widget state (important once tabs have data); no route management overhead

## Deviations from Plan

None — plan executed exactly as written. All visual specifications implemented as described.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Visual shell is complete and human-approved — n3urala1 aesthetic established
- All three tabs have GlassCard placeholders ready to receive data content
- OrbBackground and GlassCard are reusable widgets, available to any future tab
- Phase 9 Plan 03 (or next phase) can wire projectsProvider data into CodeTab/ResearchTab content

---
*Phase: 09-theme-ui-shell*
*Completed: 2026-02-20*
