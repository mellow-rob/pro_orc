---
phase: 10-card-widgets-quick-actions
plan: "02"
subsystem: ui-widgets
tags: [flutter, glassmorphism, riverpod, responsive-grid, quick-actions, hidden-projects]
dependency_graph:
  requires: [10-01]
  provides: [GsdStatusBadge, CodeProjectCard, CodeTab, EmptyState]
  affects: [10-03, 10-04]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget, LayoutBuilder responsive grid, MouseRegion hover, GestureDetector context menu]
key_files:
  created:
    - pro_orc/lib/features/shared/status_badge.dart
    - pro_orc/lib/features/code/code_project_card.dart
    - pro_orc/lib/features/shared/empty_state.dart
    - pro_orc/lib/features/.gitignore
  modified:
    - pro_orc/lib/features/code/code_tab.dart
decisions:
  - "features/.gitignore added with !code/ negation — root .gitignore has 'code/' pattern that silently ignored all of features/code/"
  - "CodeProjectCard is ConsumerStatefulWidget (not ConsumerWidget) — _isHovered hover state requires StatefulWidget lifecycle"
  - "GridView.builder with mainAxisExtent=300 (fixed height) — avoids overflow from multiline nextStep text"
  - "Hidden cards rendered in same GridView with isHiddenCard=true (0.45 opacity) — avoids layout complexity of a second grid"
  - "Sort executed at CodeTab level, not in projectsProvider — per plan locked decision"
metrics:
  duration: "3 min"
  completed_date: "2026-02-20"
  tasks_completed: 2
  files_changed: 5
---

# Phase 10 Plan 02: Code Tab Card Widgets + Quick Actions Summary

GsdStatusBadge chip widget with 5 colored states, CodeProjectCard with title/version/progress/next-step/description/quick-actions/hover-glow/right-click menu, responsive 2-4 column CodeTab grid sorted by git activity, hidden projects expandable banner, and EmptyState with NSOpenPanel scan-dir picker — the primary user-facing feature of Phase 10.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | GsdStatusBadge + CodeProjectCard widget | 0919993 | features/.gitignore, features/shared/status_badge.dart, features/code/code_project_card.dart |
| 2 | CodeTab responsive grid + EmptyState | f75a1d9 | features/code/code_tab.dart, features/shared/empty_state.dart |

## What Was Built

**GsdStatusBadge** (`features/shared/status_badge.dart`):
- Maps 5 status strings to colored badge chips: building=cyan, planning=amber-yellow, done=green, research=fuchsia, paused=amber
- Null/unknown status renders "Not Started" in textDis grey
- Container with border at 0.5 alpha, 12px border radius, 11px text, w500 weight

**CodeProjectCard** (`features/code/code_project_card.dart`):
- ConsumerStatefulWidget with `_isHovered` state for hover glow effect
- Title row: code icon + displayName (bold) + version (if present) + eye icon toggle
- Status badge row with optional parse error warning icon (amber, tooltip)
- Progress bar: ClipRRect + FractionallySizedBox + percentage label, only visible if phaseProgress != null
- Next step: "Next:" label + 3-line ellipsis text, conditional on nextStep != null
- Description: 2-line ellipsis text, conditional on description != null
- Quick actions: Terminal + Finder always visible; GitHub only if githubUrl != null; Notion only if notionUrl != null
- Hover: AnimatedContainer with cyan BoxShadow at 0.15 alpha, 180ms transition
- Right-click: GestureDetector.onSecondaryTapUp shows popup with "Ausblenden"/"Einblenden"
- `isHiddenCard` flag renders card at 0.45 opacity for visually distinguishing hidden projects

**EmptyState** (`features/shared/empty_state.dart`):
- folder_open_outlined icon (64px, textDim), German heading + message
- Optional "Scan-Ordner waehlen" OutlinedButton with cyan border

**CodeTab** (`features/code/code_tab.dart`):
- Rewritten from StatelessWidget to ConsumerStatefulWidget
- Watches projectsProvider (.when pattern) + hiddenProjectsProvider
- Filters to code projects (type == 'code' || type == null)
- Sorts by lastCommitDate descending (null last) at tab level only
- LayoutBuilder responsive grid: 2 cols (<750px), 3 cols (<1100px), 4 cols (>1100px)
- GridView.builder with mainAxisExtent=300, crossAxis/mainAxis spacing 12px
- Hidden banner: GlassCard row with count + "Alle zeigen"/"Ausblenden" toggle
- _showHidden toggle appends hidden cards to grid at 0.45 opacity
- _pickScanDir uses file_selector getDirectoryPath() + db.updateConfig() + invalidates projectsProvider
- _showDetail stub for Plan 03 wiring

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Root .gitignore silently ignored features/code/**
- **Found during:** Task 1 commit
- **Issue:** Root `.gitignore` contains `code/` pattern which matched `pro_orc/lib/features/code/` — git refused to stage the new files
- **Fix:** Created `pro_orc/lib/features/.gitignore` with `!code/` and `!code/**` negations
- **Files modified:** pro_orc/lib/features/.gitignore (created)
- **Commit:** 0919993

## Verification

- `flutter analyze` — same 5 pre-existing issues as before; zero new errors from new files
- All new lib/ files type-check cleanly: GsdStatusBadge, CodeProjectCard, CodeTab, EmptyState
- GsdStatusBadge covers 5 status values + fallback null case
- CodeProjectCard all conditional sections compile: progress bar, next step, description, quick action buttons
- CodeTab LayoutBuilder switch expression with 3 breakpoints compiles correctly
- `getDirectoryPath()` from file_selector available (added in 10-01)

## Self-Check: PASSED
