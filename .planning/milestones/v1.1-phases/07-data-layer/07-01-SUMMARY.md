---
phase: 07-data-layer
plan: 01
subsystem: database
tags: [drift, sqlite, flutter, dart, data-models, code-generation]

# Dependency graph
requires: []
provides:
  - ProjectModel, GsdData, GitData data classes for project list representation
  - AppDatabase drift SQLite database with AppConfigTable and ProjectSettingsTable
  - getConfig/updateConfig helpers with auto-insert default row on first access
  - getProjectSettings/upsertProjectSettings helpers for per-project settings
affects: [07-02-scan-service, 07-03-git-service, 07-04-project-repository, phase-08, phase-09]

# Tech tracking
tech-stack:
  added:
    - drift 2.31.0 (type-safe SQLite ORM for Flutter/Dart)
    - drift_flutter 0.2.8 (Flutter integration for drift)
    - drift_dev 2.31.0 (code generation for drift tables)
    - build_runner 2.11.1 (Dart code generation runner)
    - path_provider 2.1.5 (platform paths: getApplicationSupportDirectory)
    - path 1.9.1 (path manipulation utilities)
    - test 1.29.0 (Dart test framework for unit tests)
    - mockito 5.6.3 (mock generation for tests)
  patterns:
    - "Drift table-per-file: each Table subclass in its own file under lib/data/db/tables/"
    - "Test-injectable database: AppDatabase([QueryExecutor? e]) allows NativeDatabase.memory() injection in tests"
    - "Default-on-first-access config: getConfig() inserts row if absent, prevents empty result errors"
    - "Companion pattern: AppConfigTableCompanion/ProjectSettingsTableCompanion for partial updates and upserts"

key-files:
  created:
    - pro_orc/lib/data/models/git_data.dart
    - pro_orc/lib/data/models/gsd_data.dart
    - pro_orc/lib/data/models/project_model.dart
    - pro_orc/lib/data/db/tables/app_config_table.dart
    - pro_orc/lib/data/db/tables/project_settings_table.dart
    - pro_orc/lib/data/db/app_database.dart
    - pro_orc/lib/data/db/app_database.g.dart
  modified:
    - pro_orc/pubspec.yaml (added drift, drift_flutter, path_provider, path, drift_dev, build_runner, test, mockito)
    - pro_orc/pubspec.lock

key-decisions:
  - "Generated app_database.g.dart committed to git (not gitignored) per research recommendation — avoids requiring build_runner before every build"
  - "AppDatabase accepts optional QueryExecutor for test injection — NativeDatabase.memory() can be passed in tests without filesystem"
  - "getConfig() uses insert-then-select pattern for first-access default row — ensures id=1 always exists before updateConfig() is called"

patterns-established:
  - "Data models are plain Dart classes (not drift DataClass) — ProjectModel/GsdData/GitData are immutable value objects with const constructors"
  - "Drift tables use camelCase getters mapping to snake_case column names automatically"
  - "All drift helper methods on AppDatabase return typed drift-generated Data classes (AppConfigTableData, ProjectSettingsTableData)"

requirements-completed: []

# Metrics
duration: 2min
completed: 2026-02-19
---

# Phase 07 Plan 01: Data Models and Drift SQLite Database Summary

**Drift SQLite database with AppConfigTable and ProjectSettingsTable, plus ProjectModel/GsdData/GitData data classes — all 8 new dependencies installed and .g.dart generated**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-19T20:41:28Z
- **Completed:** 2026-02-19T20:43:52Z
- **Tasks:** 2
- **Files modified:** 9 (7 created, 2 modified)

## Accomplishments
- Three immutable data model classes (ProjectModel, GsdData, GitData) with all fields from research data model, const constructors, and empty constants
- Drift database with two tables: AppConfigTable (scan dir, ignore list, git binary path with defaults) and ProjectSettingsTable (folderId PK, projectType, displayName, typeSetAt)
- Test-injectable AppDatabase with helper methods for config and project settings CRUD
- Code generation via build_runner produced app_database.g.dart (committed to git)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add dependencies and create data models** - `cb8aa42` (feat)
2. **Task 2: Create drift database with tables and run code generation** - `2e29e94` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `pro_orc/pubspec.yaml` - Added 8 new dependencies (drift, drift_flutter, path_provider, path, drift_dev, build_runner, test, mockito)
- `pro_orc/pubspec.lock` - Updated lock file after flutter pub get
- `pro_orc/lib/data/models/git_data.dart` - GitData with lastCommitMessage, lastCommitHash, lastCommitDate, githubUrl; static empty constant
- `pro_orc/lib/data/models/gsd_data.dart` - GsdData with status, currentPhase, nextStep, phaseProgress, notionUrl, description, phasesCompleted/Total, plansCompleted/Total; static empty constant
- `pro_orc/lib/data/models/project_model.dart` - ProjectModel with folderId, displayName, path, projectType, description, gsd, git, hasParseError, isStale
- `pro_orc/lib/data/db/tables/app_config_table.dart` - AppConfigTable drift table definition with column defaults
- `pro_orc/lib/data/db/tables/project_settings_table.dart` - ProjectSettingsTable with folderId as PK
- `pro_orc/lib/data/db/app_database.dart` - AppDatabase with DriftNativeOptions, test injection, 4 helper methods
- `pro_orc/lib/data/db/app_database.g.dart` - Generated drift code (committed to git)

## Decisions Made
- Generated app_database.g.dart committed to git (not gitignored) — avoids requiring build_runner as a prerequisite for every build/CI step
- AppDatabase accepts optional QueryExecutor for test injection — downstream plans can use NativeDatabase.memory() without filesystem setup
- getConfig() inserts the default row if absent (insert-then-select pattern) — ensures id=1 row always exists before updateConfig() attempts a write

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `flutter` not in PATH for GUI app process — used full path `/opt/homebrew/share/flutter/bin/flutter` (consistent with STATE.md known issue)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Data layer foundation complete: models and database ready for all Phase 7 plans
- 07-02 (scan service), 07-03 (git service), and 07-04 (project repository) all depend on these models and the AppDatabase
- AppDatabase helper methods ready for use; scan dir and ignore list defaults are in place

---
*Phase: 07-data-layer*
*Completed: 2026-02-19*

## Self-Check: PASSED

All files verified present, commits verified in git log, key class/annotation content verified in source files.
