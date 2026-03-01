---
phase: 18-external-resource-cleanup
plan: 01
subsystem: data
tags: [external-resources, notion, github, figma, claude-memory, dart, model, service]

requires:
  - phase: 17-deletion-core
    provides: "ProjectModel with gsd.notionUrl, git.githubUrl, memory fields"
provides:
  - "ExternalResource model with ExternalResourceType enum (5 types)"
  - "detectExternalResources() top-level async function returning List<ExternalResource>"
affects:
  - 18-02-cleanup-ui (consumes detectExternalResources to build step-by-step prompts)

tech-stack:
  added: []
  patterns:
    - "Top-level function pattern (no class wrapper) matching git_reader/memory_reader"
    - "Separate try/catch per detection step for graceful degradation"
    - "seenUris Set to prevent duplicate URL reporting across detection strategies"

key-files:
  created:
    - pro_orc/lib/data/models/external_resource.dart
    - pro_orc/lib/data/services/resource_detector.dart
  modified: []

key-decisions:
  - "Reuse encodeProjectPath from memory_reader (exact path only, not fuzzy scan) for Claude Memory detection — simpler and sufficient since detector only needs existence check, not MEMORY.md contents"
  - "Cap URL scan at max 10 URLs and skip files >100KB to avoid noise from large generated files"
  - "URL regex trailing cleanup: trimRight + strip trailing punctuation (.,;:) to avoid capturing markdown punctuation as part of URLs"

patterns-established:
  - "ExternalResource: immutable const class, no empty sentinel — empty list means no resources"
  - "URL classification: domain-based matching with fallback to domain name as label"

requirements-completed: [CLN-01, CLN-02, CLN-03, CLN-04]

duration: 1min
completed: 2026-02-27
---

# Phase 18 Plan 01: ExternalResource Model + Detector Service Summary

**Pure Dart ExternalResource model and detectExternalResources() service detecting Notion, GitHub, Figma, Claude Memory, and other URLs from project metadata and .md file scanning**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-27T14:01:47Z
- **Completed:** 2026-02-27T14:02:52Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- ExternalResourceType enum with 5 values: notion, github, figma, claudeMemory, other
- ExternalResource immutable model: type, label (German), uri, hint (German deletion instructions)
- detectExternalResources() aggregates all 4 requirement categories (CLN-01 through CLN-04)
- .md file scanner traverses project root and .planning/ up to 2 levels deep with noise guards

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ExternalResource model** - `ef42eb9` (feat)
2. **Task 2: Create resource_detector service** - `8a7a8d0` (feat)

## Files Created/Modified

- `pro_orc/lib/data/models/external_resource.dart` - ExternalResource model and ExternalResourceType enum
- `pro_orc/lib/data/services/resource_detector.dart` - detectExternalResources() top-level async function

## Decisions Made

- Reused `encodeProjectPath` from `memory_reader.dart` for exact-path Claude Memory directory lookup — the detector only needs to check existence, not read MEMORY.md contents, so fuzzy matching is unnecessary overhead
- URL scan capped at 10 URLs and files >100KB skipped to avoid noise from lock files, generated code, etc.
- Trailing punctuation stripping on matched URLs (`.trimRight()` + regex strip of `.,;:`) prevents capturing markdown-adjacent punctuation as part of URLs

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing flutter analyze warnings in gsd_parser.dart, settings_tab.dart, launch_dialog.dart, and test files (14 total). None are in the new files. All pre-exist from prior phases and are out of scope per deviation rules.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ExternalResource model and detectExternalResources() ready for consumption by Phase 18 Plan 02 (cleanup UI)
- detectExternalResources(project) is the single entry point — pass any ProjectModel
- No blockers

---
*Phase: 18-external-resource-cleanup*
*Completed: 2026-02-27*

## Self-Check: PASSED

- FOUND: pro_orc/lib/data/models/external_resource.dart
- FOUND: pro_orc/lib/data/services/resource_detector.dart
- FOUND: .planning/phases/18-external-resource-cleanup/18-01-SUMMARY.md
- FOUND: commit ef42eb9 (Task 1)
- FOUND: commit 8a7a8d0 (Task 2)
