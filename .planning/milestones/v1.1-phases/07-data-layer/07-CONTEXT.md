# Phase 7: Data Layer - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Pure Dart services that scan project directories, parse GSD planning files (STATE.md, ROADMAP.md, PROJECT.md), and read git history — all verified with unit tests and without running the Flutter app. This phase builds the data layer only; UI, reactive state, and first-run wizard are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Project Discovery

- **Single scan directory** — one configurable directory (default: `~/project_orchestration/`), not separate code/research dirs
- **Flat structure** — only direct children of the scan directory are projects. No recursive scanning. User will restructure existing `code/` and `project research/` subdirectories into a flat layout
- **Directories only** — loose files in the scan directory are ignored; every subdirectory is treated as a project
- **Auto-discovery** — scanner runs automatically on app start; new directories appear as projects without manual registration
- **Configurable ignore list** — patterns for directories to skip (e.g., `.*`, `node_modules`). Stored in app config
- **Local paths only** — no network/cloud mount support
- **App config location** — `~/Library/Application Support/ProOrc/` (macOS standard)

### Project Classification (Code/Research/Custom)

- **Configurable per project** — project type is NOT determined by parent directory; it's a setting stored in the App-DB and PROJECT.md
- **Erweiterbare Typen** — data model supports user-defined types beyond Code/Research (e.g., "Design", "Docs"). UI for managing types is a future phase
- **Default for new projects** — unclassified. No type assumed until user sets one
- **Dual storage with timestamp sync** — type stored in both App-DB and PROJECT.md. When values conflict, the most recently modified source wins (requires timestamp tracking)

### Data Fields

- **PROJECT.md** — Claude decides which fields to parse based on v1.0 data model and UI needs
- **PROJECT.md name** — preferred over folder name for display. Folder name as fallback/ID
- **STATE.md** — compact overview (phase, status, progress) for cards; full details on demand (next step, blockers, velocity, etc.)
- **ROADMAP.md** — parse for phase list, milestone name, and overall phase progress per project
- **Non-GSD projects** — show name + git info + PROJECT.md data if available. No error, no warning — just display what's there
- **Unknown PROJECT.md fields** — ignored. Only defined fields are parsed
- **Stale indicator** — Claude decides best approach (git timestamp, STATE.md last activity, or combination)
- **Link validation** — Claude decides (extract only vs. optional background validation)

### Caching

- **Cache with invalidation** — parse results cached, re-parse only when file mtime changes. Faster for repeated scans

### Claude's Discretion
- DB technology choice (SQLite/drift, Hive/Isar, etc.)
- Which PROJECT.md fields to parse (based on v1.0 model and UI needs)
- Compact card layout field selection (balance info density vs. readability)
- Stale indicator approach (git-based, STATE.md-based, or combined)
- Link validation strategy (extract only vs. background check)
- Monorepo/nested project handling (pragmatic default)
- Git concurrency model (parallel with limit vs. sequential)
- Git timeout value

</decisions>

<specifics>
## Specific Ideas

- User wants to restructure from two directories (code/ + project research/) to one flat directory before this phase runs
- Project type management UI (adding custom types in-app) — noted but belongs in later phase
- First-run wizard for initial scan directory setup — noted but belongs in later phase (UI)
- "runInShell: true" on all Process.run calls (GUI app PATH issue) PLUS configurable git binary path as fallback
- Git data per project: last commit message, hash, timestamp + GitHub remote URL. Nothing more
- Parse errors should show a warning icon on the project card (graceful degradation + visual indicator)
- If scan directory doesn't exist or isn't readable: clear error message + prompt to configure in settings

</specifics>

<deferred>
## Deferred Ideas

- **UI for managing project types** — user wants to create/edit types in the app, not just config. Separate UI phase
- **First-run wizard** — guided setup on first launch to configure scan directory. UI phase (Phase 9 or 10)
- **Network/cloud mount support** — only local paths for now
- **Branch info and activity stats from git** — only basic git data (last commit + remote URL) for now
- **Log file for scanner errors** — UI-only error display for now; file logging may come later

</deferred>

---

*Phase: 07-data-layer*
*Context gathered: 2026-02-19*
