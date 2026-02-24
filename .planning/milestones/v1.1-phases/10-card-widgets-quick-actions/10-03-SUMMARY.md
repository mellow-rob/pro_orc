---
phase: 10-card-widgets-quick-actions
plan: "03"
subsystem: ui-widgets
tags: [flutter, glassmorphism, riverpod, responsive-grid, research-tab, detail-panel, modal]
dependency_graph:
  requires: [10-01, 10-02]
  provides: [ResearchProjectCard, ResearchTab, ProjectDetailPanel]
  affects: [10-04]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget, showGeneralDialog slide+fade, LayoutBuilder responsive grid, GestureDetector context menu]
key_files:
  created:
    - pro_orc/lib/features/research/research_project_card.dart
    - pro_orc/lib/features/shared/project_detail_panel.dart
  modified:
    - pro_orc/lib/features/research/research_tab.dart
    - pro_orc/lib/features/code/code_tab.dart
decisions:
  - "Notion section guard uses `gsd != null && gsd.notionUrl != null` (not `gsd?.notionUrl != null`) — avoids unnecessary_non_null_assertion warning from analyzer"
  - "ProjectDetailPanel uses showGeneralDialog (not showDialog) — enables custom slide-up + fade transitionBuilder"
  - "ResearchTab mainAxisExtent=220 (vs CodeTab 220) — research cards have less content (no progress bar, no next step)"
  - "Phase status icon uses in_progress -> arrow icon (cyan), complete -> check icon (green), default -> unchecked dot (textDim)"
metrics:
  duration: "4 min"
  completed_date: "2026-02-20"
  tasks_completed: 2
  files_changed: 4
---

# Phase 10 Plan 03: Research Tab + ProjectDetailPanel Summary

ResearchProjectCard with fuchsia accent and science icon, ResearchTab with responsive 2-4 column grid sorted alphabetically, and ProjectDetailPanel modal (slide+fade animation) showing all GSD data including phases list (Roadmap-Uebersicht) and decisions list — completing card coverage for both project types and providing deep-dive detail view.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | ResearchProjectCard + ResearchTab grid | b5fe21c | features/research/research_project_card.dart, features/research/research_tab.dart |
| 2 | ProjectDetailPanel modal + wire onTap in CodeTab and ResearchTab | ffd424c | features/shared/project_detail_panel.dart, features/code/code_tab.dart, features/research/research_tab.dart |

## What Was Built

**ResearchProjectCard** (`features/research/research_project_card.dart`):
- ConsumerStatefulWidget with `_isHovered` state for fuchsia hover glow effect
- Title row: science icon (fuchsia) + displayName (bold) + eye icon toggle
- Description: prominent 4-line text at fontSize 13 (no progress bar or next step to compete)
- Quick actions: Terminal + Finder always visible; GitHub only if githubUrl; Notion only if notionUrl
- Hover: AnimatedContainer with fuchsia BoxShadow at 0.15 alpha, 180ms transition
- Right-click: GestureDetector.onSecondaryTapUp shows popup with "Ausblenden"/"Einblenden"
- `isHiddenCard` flag renders card at 0.45 opacity

**ResearchTab** (`features/research/research_tab.dart`):
- Rewritten from StatelessWidget placeholder to ConsumerStatefulWidget
- Watches projectsProvider + hiddenProjectsProvider
- Filters to `projectType == 'research'` projects only
- Sorts alphabetically by displayName (research lacks git dates)
- LayoutBuilder responsive grid: 2 cols (<750px), 3 cols (<1100px), 4 cols (>1100px)
- GridView.builder with mainAxisExtent=220, crossAxis/mainAxis spacing 12px
- Hidden banner with fuchsia accent ("N Projekte ausgeblendet — Alle zeigen")
- EmptyState widget for zero research projects (no directory picker — research projects don't scan directories)
- `_showDetail` wired to `showProjectDetail` from Task 2

**ProjectDetailPanel** (`features/shared/project_detail_panel.dart`):
- `showProjectDetail()` top-level function using `showGeneralDialog` with slide-up + fade transition (300ms, easeOutCubic)
- Header: project type icon + name + version + X close button
- Status section: GsdStatusBadge + current phase text
- Progress bar with accent color (cyan or fuchsia by project type)
- Plans completed/total counter
- Next step: full text, not truncated
- Description: full text, not truncated
- Phases list (Roadmap-Uebersicht): each phase as icon + "Phase N: Name" + "N/M Plans"
  - complete: green check_circle_outline icon
  - in_progress: cyan arrow_circle_right_outlined icon
  - not_started: textDim radio_button_unchecked icon
- Decisions list: bullet dots + full text per decision from GsdData.decisions
- Git info: commit hash + date + clickable GitHub URL
- Notion link: clickable URL text
- Quick actions row: Terminal, Finder, GitHub, Notion (24px icons)
- barrierDismissible: true — tap outside closes panel
- Accent color: `project.projectType == 'research' ? colors.fuch : colors.cyan`

**CodeTab wiring** (`features/code/code_tab.dart`):
- Import added for `project_detail_panel.dart`
- `_showDetail` stub replaced with real `showProjectDetail(context, project)` call

## Verification

- `flutter analyze` — same 5 pre-existing issues as before; zero new errors from new files
- ResearchProjectCard: fuchsia icon + hover glow, science icon, no progress bar/badge/next step
- ResearchTab: ConsumerStatefulWidget with LayoutBuilder, hidden banner with fuchsia accent
- ProjectDetailPanel: slide+fade animation, all GSD sections, phases list, decisions list
- Both CodeTab and ResearchTab wire card onTap to showProjectDetail

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] unnecessary_non_null_assertion in Notion section**
- **Found during:** Task 2 flutter analyze
- **Issue:** `if (gsd?.notionUrl != null)` condition followed by `gsd!.notionUrl!` — analyzer warns that `!` on `notionUrl` is unnecessary within the null-checked branch
- **Fix:** Changed guard to `if (gsd != null && gsd.notionUrl != null)` which gives the analyzer enough type narrowing to omit the `!` on `notionUrl`
- **Files modified:** pro_orc/lib/features/shared/project_detail_panel.dart
- **Commit:** ffd424c (same task commit)

## Self-Check: PASSED
