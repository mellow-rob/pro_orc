# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Pro Orc** — native macOS Flutter dashboard that auto-scans configurable directories for projects, displays GSD planning status, git history, and Claude tools inventory. Menubar-only app (no Dock icon), reactive file watching, glassmorphism dark theme.

Language: German used in requirements, commit messages, and user-facing strings where appropriate.

## Build & Run Commands

All commands run from `pro_orc/` subdirectory:

```bash
flutter run -d macos                  # Debug run
flutter build macos                   # Release .app bundle
flutter test                          # All unit tests
flutter test test/data/               # Data layer tests only
flutter test test/data/gsd_parser_test.dart  # Single test file
flutter analyze                       # Dart static analysis
```

## Architecture

Three-layer architecture: **Presentation → Riverpod Providers → Pure Dart Services**

### Data Flow

```
ShellScreen (ConsumerStatefulWidget + NavigationRail)
  → IndexedStack [CodeTab, ResearchTab, ClaudeToolsTab, SettingsTab]
  → ref.watch(projectsProvider)         # FutureProvider<List<ProjectModel>>
    → ref.listen(watcherProvider)        # Invalidates on FS changes
    → projectScannerProvider.scanAll()   # Orchestrates parsing across multiple dirs
      → GsdParser (STATE.md, ROADMAP.md, PROJECT.md)
      → GitReader (Process.run with 5s timeout)
      → _inferType() content-based project classification
```

### Key Patterns

- **watcherProvider** uses `ref.keepAlive()` — never disposed, outlives widgets
- **projectsProvider** invalidates itself via `ref.listen` on watcher events — stateless reactive pattern
- **All services** are pure Dart (no Flutter imports) — unit-testable, isolate-safe
- **Process.run** always uses `runInShell: true` — macOS GUI apps don't inherit Homebrew PATH
- **Drift database** (SQLite v2) stores app config and per-project settings; `app_database.g.dart` is committed (not gitignored)
- **Tests** use real temp git repos via `createTempProject()` — no mocking
- **Multi-directory scanning**: `WatcherService.multi()` merges FS events from multiple dirs; `ProjectScanner.scanAll()` loops through `db.getScanDirs()`
- **Content-based type inference**: `_inferType()` checks for build files (pubspec.yaml, package.json, etc.) → `code`, otherwise → `research`. Overridable via DB `projectType` setting.
- **Right-click context menus** on cards: move between tabs, toggle private, ignore project

### State Management (Riverpod 3.x)

- `FutureProvider` + `ref.listen` invalidation for data that recomputes on events
- `StreamProvider` with `keepAlive` for long-lived watchers
- `ConsumerStatefulWidget` where mixins (WindowListener, TrayListener) need StatefulWidget lifecycle
- `hiddenProjectsProvider` — NotifierProvider tracking private project visibility

## macOS Platform Notes

- `LSUIElement=true` in Info.plist — menubar-only, no Dock icon
- Sandbox disabled in **both** `DebugProfile.entitlements` and `Release.entitlements`
- `tray_manager` 0.5.2 + `window_manager` 0.5.1 for native integration
- Close button hides window (not quits); tray menu has explicit "Quit"
- Window geometry persisted to SharedPreferences
- First-launch dialog for autostart opt-in

## Project Structure

```
pro_orc/                    # Flutter macOS app (the main deliverable)
  lib/
    main.dart               # Entry: ProviderScope, window/tray init
    features/
      shell/                # ShellScreen (NavigationRail), OrbBackground, GlassCard
      code/                 # CodeTab + CodeProjectCard (git activity sort)
      research/             # ResearchTab + ResearchProjectCard (alpha sort)
      claude_tools/         # ClaudeToolsTab
      settings/             # SettingsTab (scan dirs, ignore patterns, git path, autostart)
      shared/               # StatusBadge, ProjectDetailPanel, EmptyState
    providers/              # projects, watcher, database, hidden_projects
    data/models/            # ProjectModel, GsdData, GitData, PhaseInfo
    data/services/          # ProjectScanner, GsdParser, GitReader, WatcherService
    data/db/                # Drift database (v2), tables, generated code
    theme/                  # N3 color system (AppColors ThemeExtension)
    tray/                   # TrayService
    window/                 # WindowGeometryService
  test/data/                # Unit tests (real temp dirs, no mocks)

pro-orc/                    # v1.0 Next.js implementation (reference only)
.planning/                  # GSD planning docs (PROJECT.md, STATE.md, ROADMAP.md)
  phases/                   # Per-phase research, context, plans, summaries
  milestones/               # Archived milestone roadmaps
```

## UI Structure

- **NavigationRail** with 3 destinations (Code, Research, Claude Tools) + Settings icon pinned to bottom via `trailing`
- Settings at index 3 is NOT a NavigationRail destination — uses custom IconButton in `trailing`
- **GlassCard**: glassmorphism container (backdrop blur + translucent bg) used everywhere
- **OrbBackground**: animated gradient orb behind content
- **CodeProjectCard**: 3-line GSD block (status+%, progress bar, phases+plans), next step, description, quick actions
- **ResearchProjectCard**: simpler card (name, description, quick actions) — no progress bar or status badge
- **Hidden/private projects**: pinned banner at bottom of each tab, expandable to show private cards in separate grid section

## Conventions

- Models: `ProjectModel`, `GsdData` — no "Dto" suffix
- Services return empty/null on errors, not exceptions (e.g., `GitData.empty`)
- Use `withValues(alpha:)` not deprecated `withOpacity()`
- Package imports only (no relative imports)
- Business logic in services, not providers
- `GsdData.isEmpty` for semantic checks (no `==` override on GsdData)
- UI strings in German: "Privat"/"Oeffentlich", "Ignorieren", "Anzeigen"/"Verbergen"
- Accent colors: cyan for Code tab, fuchsia for Research tab

## GSD Parser Details

The parser (`gsd_parser.dart`) extracts data from `.planning/` with multi-level fallbacks:

- **Progress**: plan checkboxes `- [x] NN-NN-PLAN` → phase checkboxes `- [x] Phase N` → phases list completion → STATE.md `Progress:`/`Fortschritt:`/`Overall Progress:` line → status=done → 100%
- **Status normalization** (`_deriveStatus`): maps keywords to research|planning|building|paused|done|archived. Recognizes: shipped, complete, finish, done, build, progress, etc.
- **Phase info**: `### Phase N: Name` headings from ROADMAP, or `N of N` pattern from currentPhase string

## Current State (v2.1 — Released 2026-04-27)

v1.0-v2.0 shipped. v2.1 adds editable project titles (DB displayName override). 143 tests, ~13,500 LOC Dart.

### Build Baseline
- `flutter test`: 143 tests, 0 failures
- `flutter analyze`: 0 issues
- Distribution: `scripts/build-dmg.sh` builds DMG installer, GitHub Actions release on tag push
