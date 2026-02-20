---
phase: 10-card-widgets-quick-actions
plan: "01"
subsystem: data-layer
tags: [drift, schema-migration, gsd-parser, riverpod, quick-actions, url-launcher]
dependency_graph:
  requires: [09-02]
  provides: [isHidden-column, PhaseInfo-model, GsdData-extensions, QuickActionsService, HiddenProjectsProvider]
  affects: [10-02, 10-03, 10-04]
tech_stack:
  added: [url_launcher ^6.3.2, file_selector ^1.1.0]
  patterns: [Drift schema migration, NotifierProvider, package-imports-only]
key_files:
  created:
    - pro_orc/lib/data/models/phase_info.dart
    - pro_orc/lib/data/services/quick_actions_service.dart
    - pro_orc/lib/providers/hidden_projects_provider.dart
  modified:
    - pro_orc/lib/data/db/tables/project_settings_table.dart
    - pro_orc/lib/data/db/app_database.dart
    - pro_orc/lib/data/db/app_database.g.dart
    - pro_orc/lib/data/models/gsd_data.dart
    - pro_orc/lib/data/services/gsd_parser.dart
    - pro_orc/lib/providers/database_provider.dart
    - pro_orc/pubspec.yaml
decisions:
  - "withDefault(const Constant(false)) used for isHidden column — not clientDefault — ensures server-side default in migration"
  - "HiddenProjectsNotifier uses synchronous build() returning {} then async _loadFromDb() — sub-50ms flicker acceptable with local SQLite"
  - "GsdParser uses package imports for phase_info.dart — consistent with codebase convention"
  - "QuickActionsService is a flat class with no abstraction layer — extensible via new methods, no interface needed yet"
  - "Version regex matches first vN.N occurrence in STATE.md — picks up milestone version from frontmatter area"
metrics:
  duration: "4 min"
  completed_date: "2026-02-20"
  tasks_completed: 2
  files_changed: 10
---

# Phase 10 Plan 01: Data Layer Foundations Summary

Drift schema v2 with isHidden migration, GsdData.version/phases/decisions fields with extended parser extraction from ROADMAP.md and STATE.md, PhaseInfo model, QuickActionsService (Terminal/Finder/URL), HiddenProjectsNotifier with Drift persistence, and url_launcher + file_selector dependencies — all data-layer foundations required by Phase 10 card widget plans 02-04.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Drift migration + GsdData extensions + parser + deps | 18cb87a | project_settings_table.dart, app_database.dart, app_database.g.dart, phase_info.dart, gsd_data.dart, gsd_parser.dart, pubspec.yaml |
| 2 | QuickActionsService + HiddenProjectsProvider | 78bf296 | quick_actions_service.dart, hidden_projects_provider.dart, database_provider.dart |

## What Was Built

**Drift Schema v2:**
- `isHidden BoolColumn` added to `ProjectSettingsTable` with `withDefault(const Constant(false))`
- `AppDatabase.schemaVersion` bumped to 2 with `MigrationStrategy` that calls `addColumn` for `from < 2`
- `getHiddenProjectIds()` helper queries all rows where `isHidden = true` and returns `Set<String>` of folderIds

**PhaseInfo Model:**
- New `pro_orc/lib/data/models/phase_info.dart` with `number`, `name`, `status`, `plansCompleted`, `plansTotal` fields

**GsdData Extensions:**
- Added `version` (nullable String), `phases` (nullable List<PhaseInfo>), `decisions` (nullable List<String>) to constructor and class
- `empty` const unchanged — new fields default to null

**GsdParser Extensions:**
- `_rVersion` regex extracts first `vN.N` occurrence from STATE.md content
- `_rDecisionSection` + `_rDecisionBullet` extract bullet points from `### Decisions` section in STATE.md
- `_rPhaseEntry` regex matches `### Phase N: Name` headings in ROADMAP.md; per-phase block parsed for plan checkbox counts and `N/N plans complete` markers; status derived as `complete`/`in_progress`/`not_started`

**QuickActionsService:**
- `openInTerminal(String path)` — `open -a Terminal <path>` via `Process.run`
- `openInFinder(String path)` — `open <path>` via `Process.run`
- `openUrl(String url)` — `launchUrl(Uri)` via url_launcher; silently returns on null parse

**HiddenProjectsProvider:**
- `HiddenProjectsNotifier extends Notifier<Set<String>>`
- `build()` returns `{}` synchronously then async `_loadFromDb()` sets state from Drift query
- `toggle(String folderId)` upserts via `ProjectSettingsTableCompanion` with `isHidden: Value(nowHidden)` and updates local state immediately

**Dependencies:** `url_launcher ^6.3.2` and `file_selector ^1.1.0` added to pubspec.yaml.

## Verification

- `flutter analyze` — no errors in modified files; 5 pre-existing issues in test files (unrelated to this plan)
- `flutter test test/data/` — 63/63 tests pass, zero regressions
- `app_database.g.dart` contains `isHidden` field in `ProjectSettingsTableData` and `ProjectSettingsTableCompanion`
- `GsdData` constructor accepts `version`, `phases`, `decisions` parameters

## Deviations from Plan

None — plan executed exactly as written. The pre-existing `widget_test.dart` error (`MyApp` isn't a class) was logged as out-of-scope.

## Deferred Items

- `test/widget_test.dart:16` — `MyApp` reference is stale (default Flutter scaffold test); pre-existing, unrelated to this plan
- `lib/features/shell/launch_dialog.dart:12` — `withOpacity()` deprecation; deferred from 09-01 per deferred-items.md

## Self-Check: PASSED
