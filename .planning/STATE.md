# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-19)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** Phase 11 — Claude Tools Panel (v1.1)

## Current Position

Phase: 11 of 11 (Claude Tools Panel) — IN PROGRESS
Plan: 2 of 3 complete (11-02 complete — provider chain + full tab UI, 3 card types)
Status: Phase 11 in progress — Plan 03 (if exists) or phase complete
Last activity: 2026-02-23 — 11-02 complete: claudeToolsWatcherProvider + claudeToolsProvider + ClaudeToolsTab + SkillCard + PluginCard + McpServerCard

Progress: [##############░░░░░░] ~70% (v1.1, 14/~20 plans complete)

## Performance Metrics

**Velocity (v1.0 reference):**
- Total plans completed: 12
- Average duration: ~2 min/plan
- Total execution time: ~0.35 hours

**v1.1 Velocity:**
- Plans completed: 4
- Average duration: ~10 min/plan

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 06    | 01   | 14 min   | 2     | 40    |
| 06    | 02   | 7 min    | 2     | 6     |
| 06    | 03   | ~15 min  | 2     | 0     |
| 07    | 01   | 2 min    | 2     | 9     |
| 07    | 02   | 3 min    | 3     | 2     |
| 07    | 03   | 6 min    | 3     | 4     |
| 07    | 04   | 3 min    | 3     | 2     |
| 08    | 01   | 7 min    | 2     | 4     |
| 08    | 02   | 3 min    | 2     | 5     |
| 09    | 01   | ~3 min   | 2     | 4     |
| 09    | 02   | ~20 min  | 3     | 6     |
| 10    | 01   | 4 min    | 2     | 10    |

*Updated after each plan completion*
| 10    | 02   | 3 min    | 2     | 5     |
| 10    | 03   | 4 min    | 2     | 4     |
| 10    | 04   | ~2 min   | 1     | 0     |
| 11    | 01   | 3 min    | 2     | 3     |
| 11    | 02   | 2 min    | 2     | 6     |

## Accumulated Context

### Decisions

Full decision log in PROJECT.md Key Decisions table.
v1.0 decisions archived to milestones/v1.0-ROADMAP.md.

**v1.1 key architectural decisions (pre-build):**
- Phase 6: Sandbox must be disabled in BOTH entitlement files and verified in `flutter build macos`, not just `flutter run`
- Phase 6: AppDelegate.swift must return false from `applicationShouldTerminateAfterLastWindowClosed` or closing window quits app
- Phase 7: Use `runInShell: true` on all `Process.run` calls — GUI app PATH does not include Homebrew git
- Phase 8: `watcherProvider` uses `ref.keepAlive()` — never disposed; `projectsProvider` invalidates on watcher events
- 08-01: WatcherService uses StreamController.broadcast() with permanent internal subscription — DirectoryWatcher.ready hangs without active listener; eager construction ensures ready is safely awaitable
- 08-01: Debounce applied on StreamController broadcast stream, not directly on DirectoryWatcher.events — allows independent debounced subscriptions per caller
- Phase 9: All OKLCH design tokens must be pre-converted to sRGB hex before Phase 9 begins (use oklch.com)

**v1.1 decisions made during execution:**
- 09-01: AppColors uses static const dark instance — avoids runtime allocation, const-propagates into ThemeData.extensions
- 09-01: No border on GlowBorderShell (locked decision) — Border.all removed, only glow BoxShadow remains
- 09-01: withValues(alpha:) replaces withOpacity() in all touched files — Flutter 3.38+ compliance
- 09-02: OrbBackground placed as Positioned.fill OUTSIDE Scaffold in Stack — orbs bleed behind NavigationRail and all tabs
- 09-02: BackdropFilter blendMode: BlendMode.src eliminates white halo artifact on dark glassmorphism cards
- 09-02: Three AnimationControllers with different durations (18s/23s/28s) create natural desync without explicit phase offsets
- 09-02: RepaintBoundary wraps CustomPaint — isolates orb animation repaints from parent widget tree
- 07-02: GsdParseResult is a local class in gsd_parser.dart (not a shared model) — belongs to parser's contract, not the data model layer
- 07-02: Test assertions use result.gsd.isEmpty (semantic) over equals(GsdData.empty) — GsdData lacks == override, semantic check is more appropriate
- 07-03: Real temp git repos used in TDD tests (no mocking) — createTempGitRepo() helper creates actual git init + commit in systemTemp
- 07-03: meta package added as explicit dependency (was transitive-only) — dart analyze requires direct dep for imported packages
- 07-04: updateConfig() is a no-op if db row absent — call getConfig() first in tests to trigger insert-on-first-access before writing config
- 07-04: ProjectScanner reads ignore patterns from DB even when scanDirOverride is provided — full config integration in override mode
- 07-03: gitBinary parameter on all public git service functions — enables Homebrew git path configuration from AppConfig
- 07-01: Generated app_database.g.dart committed to git (not gitignored) — avoids build_runner as prerequisite for every build
- 07-01: AppDatabase accepts optional QueryExecutor — NativeDatabase.memory() injectable for unit tests without filesystem
- 07-01: getConfig() uses insert-then-select pattern for id=1 default row — ensures row always exists before updateConfig() writes
- 06-03: Release .app confirmed passing all NAT-01 through NAT-04 requirements — Phase 6 complete
- 06-03: Both entitlement files verified sandbox=false in codesigned binary — two-entitlements-file trap successfully avoided
- 06-01: Flutter installed via homebrew at `/opt/homebrew/share/flutter` (not `/Users/rob/code/flutter` as .zshrc expected) — update .zshrc or use full path
- 06-01: Entitlement files are `DebugProfile.entitlements` / `Release.entitlements` (Flutter 3.41.1, no `Runner-` prefix)
- 06-01: `applicationSupportsSecureRestorableState` must be kept in AppDelegate — Flutter build warns if removed
- 06-02: `trayManager.ensureInitialized()` does not exist in tray_manager 0.5.2 — TrayService.init() handles all setup
- 06-02: `MenuItem` imported directly from tray_manager; no need to hide from flutter/material.dart
- 06-02: `dart:ui` must be imported explicitly for `Size` and `Offset` types in window_geometry_service.dart
- [Phase 08]: ConsumerStatefulWidget (not ConsumerWidget) for ShellScreen — WindowListener and TrayListener mixins require StatefulWidget lifecycle; ref available directly on ConsumerState
- [Phase 08]: ref.listen in FutureProvider body for watcher-driven invalidation — listen registers side-effect callback without rebuild dependency; invalidateSelf() on hasValue triggers fresh scanAll()
- 10-01: withDefault(const Constant(false)) for isHidden column — ensures server-side default in Drift migration, not clientDefault
- 10-01: HiddenProjectsNotifier synchronous build() returning {} then async _loadFromDb() — sub-50ms flicker acceptable with local SQLite
- 10-01: QuickActionsService is a flat class, no abstraction layer — extensible via new methods as needed (Claude Code, VS Code planned)
- 10-01: GsdParser version regex matches first vN.N in STATE.md content — picks up milestone version from top of file
- 10-02: features/.gitignore with !code/ negation required — root .gitignore 'code/' pattern silently ignored features/code/ directory
- 10-02: CodeProjectCard is ConsumerStatefulWidget — _isHovered hover state requires StatefulWidget lifecycle
- 10-02: GridView.builder with mainAxisExtent=300 (fixed height) — avoids overflow from multiline nextStep text in cards
- 10-02: Sort executed at CodeTab level only, not in projectsProvider — preserves provider's sorting-agnostic contract
- 10-03: Notion guard uses `gsd != null && gsd.notionUrl != null` (not `gsd?.notionUrl != null`) — avoids unnecessary_non_null_assertion analyzer warning
- 10-03: ProjectDetailPanel uses showGeneralDialog (not showDialog) — enables custom slide-up + fade transitionBuilder
- 10-03: ResearchTab mainAxisExtent=220 (vs CodeTab 300) — research cards have less content (no progress bar, no next step)
- 11-01: ClaudeToolsScanner uses claudeDirOverride constructor param — injectable temp-dir for tests, mirrors ProjectScanner pattern
- 11-01: Skills without SKILL.md use folder name as display name, null description — forgiving fallback, no skills silently dropped
- 11-01: Amber/Emerald/Violet for Skills/Plugins/MCP accents — warm/green/purple semantics, distinct from existing cyan/fuchsia
- 11-02: claudeToolsWatcherProvider mirrors watcherProvider exactly — keepAlive, WatcherService single-dir, yield* events
- 11-02: claudeToolsProvider mirrors projectsProvider exactly — ref.listen hasValue before invalidateSelf, direct ClaudeToolsScanner().scanAll()
- 11-02: ClaudeToolsTab is ConsumerStatefulWidget — TextEditingController requires initState/dispose lifecycle
- 11-02: Wrap widget for mini card grid — natural flow, no fixed height constraint vs GridView.builder

### Pending Todos

- Update ~/.zshrc to add `/opt/homebrew/share/flutter/bin` to PATH (or symlink to expected `/Users/rob/code/flutter`)
- Fix pre-existing withOpacity() in launch_dialog.dart:12 (deferred from 09-01, see deferred-items.md)

### Blockers/Concerns

- ~~Phase 6: `tray_manager` + `window_manager` version compatibility~~ — RESOLVED: tray_manager 0.5.2 + window_manager 0.5.1 both installed, flutter build macos succeeds
- ~~Phase 8: dart-lang/watcher#79 (isDirectory assertion crash)~~ — RESOLVED: Fixed in watcher 1.2.1; WatcherService also adds handleError defensive guard per locked decision

## Session Continuity

Last session: 2026-02-23
Stopped at: Completed 11-02-PLAN.md (provider chain + Claude Tools tab UI + 3 card types)
Resume file: .planning/phases/11-claude-tools-panel/11-02-SUMMARY.md
