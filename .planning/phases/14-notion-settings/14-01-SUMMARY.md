---
phase: 14-notion-settings
plan: 01
subsystem: database, settings, ui
tags: [notion, drift, sqlite, aes, encryption, flutter, riverpod]

# Dependency graph
requires:
  - phase: 13-memory-ui-actions
    provides: "Drift DB v2 schema and AppConfigTable pattern"
provides:
  - "Drift DB schema v3 with notionApiKey + notionParentPageId columns"
  - "AES-CBC encryption helper for Notion API key storage"
  - "Settings UI section for Notion API Key (obscured) and Parent Page ID"
affects:
  - 17-research-project-creation

# Tech tracking
tech-stack:
  added: ["encrypt ^5.0.3 (AES-CBC via pointycastle)"]
  patterns:
    - "Top-level encrypt/decrypt functions (consistent with memory_reader/git_reader pattern)"
    - "Encryption at UI layer before DB write; decryption at load time"
    - "updateNotionConfig() accepts pre-encrypted values"

key-files:
  created:
    - pro_orc/lib/data/services/notion_crypto.dart
    - pro_orc/test/data/notion_crypto_test.dart
  modified:
    - pro_orc/lib/data/db/tables/app_config_table.dart
    - pro_orc/lib/data/db/app_database.dart
    - pro_orc/lib/data/db/app_database.g.dart
    - pro_orc/lib/features/settings/settings_tab.dart
    - pro_orc/pubspec.yaml
    - pro_orc/pubspec.lock

key-decisions:
  - "AES-CBC with static hardcoded key for obfuscation-level security (not cryptographic) — prevents plaintext in SQLite"
  - "Encryption happens in UI layer before calling updateNotionConfig(), keeping DB helper agnostic of crypto"
  - "API Key uses obscureText: true in TextField; Parent Page ID is plain text (not a secret)"

patterns-established:
  - "Notion crypto: encryptNotionKey/decryptNotionKey top-level functions in notion_crypto.dart"
  - "Schema migration: onUpgrade checks from < N before adding each new set of columns"

requirements-completed:
  - NOT-01
  - NOT-02

# Metrics
duration: 4min
completed: 2026-02-24
---

# Phase 14 Plan 01: Notion Settings Summary

**AES-CBC encrypted Notion API key and Parent Page ID settings persisted in Drift DB v3 with obscured UI field**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-24T14:11:02Z
- **Completed:** 2026-02-24T14:15:35Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- AppConfigTable extended with notionApiKey (encrypted) and notionParentPageId columns via schema v3 migration
- notion_crypto.dart provides encryptNotionKey/decryptNotionKey using AES-CBC (encrypt ^5.0.3 package)
- Settings tab Notion Integration section with obscured API key field and plain Parent Page ID field
- 4 unit tests verifying round-trip, empty string handling, non-plaintext output, and garbage input resilience

## Task Commits

Each task was committed atomically:

1. **Task 1: Drift DB schema v3 + encryption helper** - `cc2d341` (feat)
2. **Task 2: Notion settings section in Settings tab** - `a916fd2` (feat)

**Plan metadata:** committed with SUMMARY.md

## Files Created/Modified
- `pro_orc/lib/data/services/notion_crypto.dart` - AES-CBC encrypt/decrypt top-level functions
- `pro_orc/test/data/notion_crypto_test.dart` - 4 unit tests for encryption round-trip
- `pro_orc/lib/data/db/tables/app_config_table.dart` - Added notionApiKey + notionParentPageId columns
- `pro_orc/lib/data/db/app_database.dart` - Schema v3 migration + updateNotionConfig() helper
- `pro_orc/lib/data/db/app_database.g.dart` - Regenerated Drift code
- `pro_orc/lib/features/settings/settings_tab.dart` - Notion Integration settings section
- `pro_orc/pubspec.yaml` - Added encrypt ^5.0.3
- `pro_orc/pubspec.lock` - Updated lock file

## Decisions Made
- Used AES-CBC with a static hardcoded 32-byte app key — this provides obfuscation (not cryptographic security) to prevent the API key appearing as plaintext in the SQLite file. Appropriate for a single-user desktop app.
- Encryption/decryption happens in the UI layer before calling `updateNotionConfig()`, keeping the DB helper crypto-agnostic and consistent with the existing `updateConfig()` pattern.
- Parent Page ID stored as plaintext (it is not a secret — it is a public Notion page reference).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Pre-existing test failures in `widget_test.dart` and `project_scanner_test.dart` were confirmed pre-existing via git stash verification. The 14 flutter analyze issues are all pre-existing (gsd_parser.dart, launch_dialog.dart, test files).

## User Setup Required
None - no external service configuration required at this stage. Phase 17 will implement the actual Notion API calls that will use these stored credentials.

## Next Phase Readiness
- Notion API key and Parent Page ID fields are available in the Settings tab
- DB schema v3 is stable; `updateNotionConfig()` / `getConfig()` ready for Phase 17 use
- Phase 17 (Research project creation with Notion page) can read credentials via `getConfig().notionApiKey` (decrypt before use with `decryptNotionKey()`)

---
*Phase: 14-notion-settings*
*Completed: 2026-02-24*

## Self-Check: PASSED

- notion_crypto.dart: FOUND
- notion_crypto_test.dart: FOUND
- 14-01-SUMMARY.md: FOUND
- Commit cc2d341 (Task 1): FOUND
- Commit a916fd2 (Task 2): FOUND
