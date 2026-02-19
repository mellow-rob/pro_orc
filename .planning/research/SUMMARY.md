# Project Research Summary

**Project:** Pro Orc v1.1 — Flutter macOS Native Desktop Rewrite
**Domain:** macOS native desktop app — project orchestration dashboard
**Researched:** 2026-02-19
**Confidence:** MEDIUM-HIGH

## Executive Summary

Pro Orc v1.1 is a full rewrite of a Next.js web dashboard into a native macOS Flutter desktop application. The core motivation is eliminating the browser and dev server dependency while adding menubar-app behavior — a tray icon that exposes the dashboard from any context without a browser tab. This is a well-understood Flutter pattern, but it requires careful attention to macOS-specific plumbing (App Sandbox, AppDelegate.swift, entitlements) that must be established before any business logic is written. The research strongly indicates that skipping this foundation work causes rewrites.

The recommended stack is Flutter 3.29 + Dart 3.x + Riverpod 3.x for state, with `tray_manager` and `window_manager` for menubar integration, `watcher` for filesystem watching, and `dart:io Process.run` for git operations. The entire Next.js client/server architecture collapses into a single Dart process: the SSE layer disappears, `StreamController.broadcast()` replaces it, and `StreamBuilder` widgets subscribe directly. Every v1.0 feature has a direct, well-understood Flutter equivalent. No novel architectural experiments are required.

The single biggest risk is the macOS App Sandbox. It blocks all filesystem reads outside the app container and all subprocess execution — silently in release builds while appearing to work in `flutter run`. Disabling the sandbox in both entitlement files must happen in Phase 1, before any service code is written. The second highest risk is the menubar-app architecture: `tray_manager` manages the icon but window show/hide requires `window_manager` and native Swift AppDelegate changes that cannot be hot-reloaded. Both of these must be verified working before building the data layer.

---

## Key Findings

### Recommended Stack

Flutter 3.29 with Dart 3 is the correct target. macOS desktop is a Tier 1 Flutter platform with Skia/Metal rendering (Impeller is not yet default on macOS desktop — use Skia without special flags). Riverpod 3.x is the community consensus for reactive state in medium-complexity Flutter apps: compile-time safety, no BuildContext dependency, and automatic disposal. The `leanflutter` packages (`tray_manager` 0.5.0, `window_manager` 0.4.x) are the standard for macOS menubar integration and are designed to work together. The Dart-native `watcher` package is the direct chokidar equivalent, wrapping macOS FSEvents. Git integration should use `dart:io Process.run` with `runInShell: true` — the `git` package is optional; raw subprocess calls are simpler for the Pro Orc use case.

**Core technologies:**
- Flutter 3.29 + Dart 3.x: macOS Tier 1 desktop target, Skia/Metal rendering — no special flags needed
- flutter_riverpod ^3.2.1: reactive state with compile-time safety, `AsyncNotifier` + `StreamProvider` patterns
- tray_manager ^0.5.0: NSStatusItem menubar icon — the single native differentiator vs web v1.0
- window_manager ^0.4.x: native window show/hide/position — required companion to tray_manager
- watcher ^1.x: FSEvents-backed directory watching — direct chokidar replacement, Dart team maintained
- dart:io (built-in): filesystem reads, `Process.run` for git and shell commands — no extra packages
- freezed ^2.x: immutable data models with `copyWith` — for `CodeProject`, `ResearchProject`, `GitInfo`
- shared_preferences ^2.3.x: window position persistence via NSUserDefaults

**Critical non-recommendation:** Do NOT use `macos_ui` package — it imposes native HIG styling that conflicts with the custom n3urala1 glassmorphism design. Do NOT add a local database (Hive, Isar, SQLite) — the filesystem IS the database. Avoid `oklch` pub.dev package (v0.0.2, low popularity) — convert OKLCH design tokens to sRGB hex at design time via oklch.com instead.

See full stack research: `.planning/research/STACK.md`

### Expected Features

The feature set is a v1.0 port to native plus one primary differentiator (menubar tray). Research confirmed the full v1.0 feature inventory by reading source code directly. Every v1.0 feature has a straightforward Flutter/Dart equivalent.

**Must have (table stakes — v1.1 launch):**
- Card grid for code and research projects with all v1.0 data fields (status, progress, next step, git commit, stale badge)
- Tab navigation: Code / Research / Claude Tools
- Directory scanner (`~/code/` and `~/project research/`) via `dart:io Directory.list()`
- `.planning/` YAML parser for GSD status, phase/plan counts, next step
- Git data reader (last commit message + timestamp) via `Process.run('git', ['log', ...])`
- File system watcher with 350ms debounce via `StreamController.broadcast()`
- Quick actions: Terminal.app, Finder, GitHub URL, Notion URL
- Claude Tools panel (Skills, MCP, Plugins from `~/.claude/`)
- n3urala1 dark theme: cyan/fuchsia OKLCH-converted colors, glassmorphism, atmospheric orbs
- Menubar tray icon with show/hide window — the primary native differentiator
- Window position/size persistence

**Should have (v1.1.x — add after core is stable):**
- Global keyboard shortcut (show/hide) via `hotkey_manager`
- macOS native app menu (Cmd+C/Q/etc.) via `PlatformMenuBar`
- macOS notifications for stale projects via `flutter_local_notifications`

**Defer (v1.2+):**
- Search/filter across projects
- Configurable terminal app (iTerm2, Warp, Ghostty)
- Inline markdown rendering (`flutter_markdown`)
- Project detail side panel

**Anti-features (explicitly do not build):**
- Light mode: intentionally dark; no user demand for a single-developer personal tool
- App Store distribution: sandbox blocks programmatic filesystem access to arbitrary directories
- SSE/HTTP server inside Flutter: eliminated by same-process pub/sub
- Multi-window / WebView / cloud sync: scope creep

See full features research: `.planning/research/FEATURES.md`

### Architecture Approach

The architecture is a four-layer Dart application: models (pure Dart, no Flutter imports — usable in isolates), services (pure Dart business logic, no Riverpod — unit-testable), providers (thin Riverpod wiring layer, no business logic), and widgets (Flutter only, all data via `ref.watch()`). The critical structural insight: the Next.js server/client boundary disappears entirely. There is no HTTP layer. `StreamController.broadcast()` is the direct SSE replacement; `StreamBuilder` widgets are the `EventSource` replacement. The watcher and the UI are in the same Dart process.

**Major components:**
1. `ProjectScannerService` — walks `~/code/` and `~/project research/`; direct port of `lib/scanner.ts`
2. `GsdParser` — reads `.planning/STATE.md`, `ROADMAP.md`, `PROJECT.md`; same regex patterns as `lib/parser.ts`
3. `GitReaderService` — `Process.run('git', ['log', '-1', ...])` with timeout wrapper; replaces simple-git
4. `WatcherService` — `DirectoryWatcher` streams merged via `StreamGroup`; replaces chokidar singleton
5. `ToolsScannerService` — walks `~/.claude/` for Skills/MCP/Plugins; direct port of `lib/tools-scanner.ts`
6. Riverpod providers (`projectsProvider`, `watcherProvider`, `toolsProvider`) — thin wiring, no logic
7. `platform/tray.dart` + `platform/window_manager.dart` — all macOS-specific integration isolated here
8. Git isolate worker — `Isolate.run()` with 4-concurrent cap for initial scan enrichment

**Key pattern:** `watcherProvider` uses `ref.keepAlive()` — never disposed. `projectsProvider` uses `ref.listen(watcherProvider)` to trigger `ref.invalidateSelf()` on any filesystem change. This is the exact replacement for the chokidar → SSE → React re-render chain in v1.0.

See full architecture research: `.planning/research/ARCHITECTURE.md`

### Critical Pitfalls

1. **macOS App Sandbox blocks all filesystem reads** — Disable `com.apple.security.app-sandbox` in BOTH `DebugProfile.entitlements` AND `Release.entitlements` in Phase 1. Test with a built `.app`, not `flutter run`. Debug builds silently succeed; release builds silently fail. Recovery is easy (edit XML, rebuild) but discovering it late wastes implementation effort.

2. **`Process.run('git')` PATH not inherited from shell** — macOS GUI apps get a minimal LaunchServices PATH (`/usr/bin:/bin`). Homebrew git at `/opt/homebrew/bin/git` is invisible. Use `runInShell: true` (simplest fix) or resolve git path at startup against known candidate paths. Always wrap `Process.run` in `.timeout(Duration(seconds: 10))` — on Apple Silicon in debug mode, subprocess calls can hang indefinitely (confirmed Flutter issue #95805).

3. **Menubar architecture requires native Swift changes** — `tray_manager` handles the icon; `window_manager` handles show/hide. But `LSUIElement` requires `Info.plist` modification, and `AppDelegate.swift` must return `false` from `applicationShouldTerminateAfterLastWindowClosed` or closing the window quits the app. Swift code cannot be hot-reloaded. Establish the full menubar pattern in Phase 1 — if this is wrong, it's a Phase 1 rewrite, not a late one.

4. **Dart file watcher is not chokidar** — The `watcher` package omits some directory-create events (dart-lang/sdk#62124), coalesces rapid changes, and has an `isDirectory` assertion crash on macOS (dart-lang/watcher#79). Wrap all watcher events with a 350ms debounce `Timer`. Never rely on directory-create events alone.

5. **`BackdropFilter` glassmorphism has multiple rendering bugs** — White halo on dark backgrounds (Flutter issue #173530) is directly relevant to the n3urala1 dark theme. Fix: wrap every `BackdropFilter` in `RepaintBoundary` + `ClipRRect`, keep blur sigma between 5–15, avoid blur inside `ListView`. Establish the glassmorphism pattern once in the theming phase and reuse it.

6. **OKLCH colors cannot be used directly in Flutter** — CSS OKLCH values copied to `Color()` produce wrong colors (misinterpreted as RGB). Pre-convert all OKLCH design tokens to sRGB hex at design time using oklch.com. Store as named `Color` constants in a single file.

7. **Entitlement files are never automatically kept in sync** — `DebugProfile.entitlements` and `Release.entitlements` must be edited manually as XML (never via Xcode Capabilities UI, which creates a third file). Always add any entitlement to both files simultaneously.

See full pitfalls research: `.planning/research/PITFALLS.md`

---

## Implications for Roadmap

Research is unambiguous about phase ordering. The dependency graph is clear: native plumbing must be verified before data services, data services before Riverpod providers, providers before widgets. The architecture research provides explicit build order with rationale. Use it directly.

### Phase 1: Native Foundation
**Rationale:** The sandbox and menubar architecture are the two highest-risk items in the entire project. Both are macOS-native concerns that block everything downstream. A sandbox misconfiguration discovered in Phase 4 means rebuilding services. A wrong menubar architecture discovered in Phase 5 means rewriting UI. Validate both before writing a single line of business logic.
**Delivers:** Working Flutter macOS app with tray icon, show/hide main window, correct entitlements in both files, `LSUIElement` suppressing Dock icon, `AppDelegate.swift` keeping app alive when window closes. Verified in both `flutter run` AND `flutter build macos`.
**Addresses:** Menubar tray icon (primary native differentiator), window bounds persistence scaffold
**Avoids:** Pitfalls 1 (sandbox), 3 (menubar AppDelegate), 7 (entitlement sync), platform hot reload workflow, tray_manager + app_links conflict, window z-order bug

### Phase 2: Data Layer (Models + Services + Git)
**Rationale:** Models have no dependencies and define data shapes for everything else. Services are pure Dart and unit-testable without Flutter infrastructure. Git integration needs PATH resolution and timeout wrappers validated before being wired into providers. The architecture research explicitly recommends proving git subprocess behavior before combining it with Riverpod.
**Delivers:** `models/` (sealed `Project`, `GsdState`, `GitInfo`, `ClaudeTool`), `services/project_scanner.dart`, `services/gsd_parser.dart`, `services/git_reader.dart` with `runInShell: true` and `.timeout()` wrappers, unit tests for parsing logic, git isolate worker with 4-concurrent cap.
**Uses:** `dart:io`, `yaml` package, `path` + `path_provider`, `freezed` for models
**Avoids:** Pitfalls 2 (git PATH), 3 (process hang/timeout)

### Phase 3: Reactive State (Riverpod Providers + Filesystem Watcher)
**Rationale:** Providers are thin wiring; services must exist before providers can wrap them. The watcher requires debounce from day one. The `ref.keepAlive()` pattern on `watcherProvider` and `ref.listen` → `ref.invalidateSelf()` on `projectsProvider` is the core live-update architecture. Validate this chain end-to-end before building UI on top of it.
**Delivers:** `providers/watcher_provider.dart` (StreamProvider + keepAlive), `services/watcher_service.dart` (DirectoryWatcher + StreamGroup merge + 350ms debounce), `providers/projects_provider.dart` (AsyncNotifier + ref.listen), `providers/tools_provider.dart`. End-to-end test: edit `STATE.md` → data changes without app restart.
**Uses:** `flutter_riverpod` ^3.2.1, `riverpod_annotation`, `build_runner`, `watcher` package
**Avoids:** Pitfalls 4 (watcher event coalescing), 11 (state over-engineering)

### Phase 4: Theme + UI Shell
**Rationale:** The n3urala1 theme must exist before any card widgets — all components reference theme colors. OKLCH→sRGB conversion constants must be established here. The glassmorphism pattern must be defined once and reused to avoid ad-hoc blur additions that accumulate rendering bugs.
**Delivers:** `ui/theme/app_theme.dart` with named `Color` constants (pre-converted from OKLCH), dark `ThemeData`, `TabBar` + `TabBarView` navigation scaffold, atmospheric background orbs (Stack + Positioned + RadialGradient), glassmorphism widget pattern (`RepaintBoundary` + `ClipRRect` + `BackdropFilter`), `ui/windows/main_window.dart` layout shell.
**Addresses:** n3urala1 dark theme, tab navigation (Code / Research / Claude Tools)
**Avoids:** Pitfalls 5 (BackdropFilter white halo), 6 (OKLCH colors), BackdropFilter performance in scrollable lists

### Phase 5: Card Widgets + Live Updates
**Rationale:** Widgets need providers (Phase 3) and theme (Phase 4). Build atom widgets first (PhaseBadge, GitInfoRow, QuickActions), then molecule widgets (ProjectCard, ResearchCard), then wire into the layout. Live-update end-to-end test belongs here: verify the full chain from `watcher` event → `projectsProvider` invalidation → card rebuild.
**Delivers:** `ui/widgets/phase_badge.dart`, `ui/widgets/git_info_row.dart`, `ui/widgets/quick_actions.dart`, `ui/widgets/project_card.dart`, `ui/widgets/research_card.dart`, `GridView.builder` with `SliverGridDelegateWithMaxCrossAxisExtent`, stale detection badge, private/visible toggle, relative time formatting, live-update verified end-to-end.
**Addresses:** All P1 card features: status, progress, next step, git commit, stale badge, private toggle, quick actions (Terminal, Finder, GitHub, Notion)

### Phase 6: Claude Tools Panel
**Rationale:** Independent feature with no dependencies on card widgets. Completes the three-tab layout. Does not block any other phase — safe to leave until core feature parity is confirmed.
**Delivers:** `services/tools_scanner.dart` (`~/.claude/` walk, JSON/YAML parsing for Skills/MCP/Plugins), `ui/widgets/tools_panel.dart`, Tools tab fully functional.
**Addresses:** Claude Tools panel (Skills, MCP, Plugins)

### Phase 7: Polish + v1.1.x Native Features
**Rationale:** After core feature parity is confirmed, add native-only differentiators scoped to v1.1.x. Global hotkey requires window behavior to be stable. Notifications require the data pipeline to be solid. App menu is low-cost polish.
**Delivers:** Global keyboard shortcut (`hotkey_manager`), macOS native app menu (`PlatformMenuBar`), macOS notifications for stale projects (`flutter_local_notifications`), window bounds restoration on launch.
**Addresses:** v1.1.x features from FEATURES.md

### Phase Ordering Rationale

- **Native plumbing first:** The macOS sandbox and menubar architecture are the only items that cannot be fixed cheaply late in the project. Both require testing in `flutter build macos` (not `flutter run`). Discovering either failure late means rewriting previously completed work.
- **Models before services, services before providers:** This is the architecture's explicit dependency chain. Skipping it creates circular dependencies and untestable code. Services are testable without any Flutter infrastructure — validating parsing logic in unit tests is faster than running the full app.
- **Theme before widgets:** All card widgets reference theme tokens. Building widgets before theme forces color changes to cascade across every widget file.
- **Tools panel last:** It is entirely independent of the card pipeline. Cannot block any other phase.
- **7-phase plan maps directly to the ARCHITECTURE.md build order** with one addition (Phase 7 for v1.1.x polish).

### Research Flags

Phases needing deeper research during planning:
- **Phase 1 (Native Foundation):** The menubar-only app pattern (LSUIElement + AppDelegate + window_manager interaction) has multiple known issues across package versions. Implement against the community template (github.com/mynameiskenlee/flutter_macos_menubar_example) and verify `tray_manager` version compatibility before starting. This phase warrants step-by-step verification.
- **Phase 3 (Reactive State):** Check dart-lang/watcher#79 (isDirectory assertion crash) — if still open in the current package version, design a try/catch wrapper for directory events before building the full provider. Also verify `StreamGroup.merge()` behavior with multiple `DirectoryWatcher` instances before committing to the pattern.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Data Layer):** Pure Dart filesystem + subprocess operations. Well-documented. Git PATH resolution already documented with three concrete options in PITFALLS.md.
- **Phase 4 (Theme + UI):** Flutter theming and `BackdropFilter` are well-documented. OKLCH conversion approach is clear. Glassmorphism mitigation pattern is already specified.
- **Phase 5 (Card Widgets):** `GridView.builder`, `StreamBuilder`, `ref.watch` — standard Flutter patterns with high-confidence documentation.
- **Phase 6 (Claude Tools):** Direct port of `lib/tools-scanner.ts`. Same file-walking logic, different I/O API.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Flutter/Dart selection is HIGH; exact package versions (tray_manager 0.5.0, window_manager 0.4.x, riverpod 3.2.1) are MEDIUM — confirmed directionally via WebSearch but not directly fetched from pub.dev. Pin versions before implementation. |
| Features | HIGH | v1.0 feature inventory sourced directly from reading source code. Flutter macOS API equivalents verified against official Flutter docs. Web-to-native mapping table is solid. |
| Architecture | MEDIUM-HIGH | Layer structure and provider patterns are well-established Flutter community patterns. Isolate approach for git is documented. Main uncertainty is `watcher` package behavior with directory events on macOS (open issue). |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls (sandbox, git PATH, process hang) verified against open GitHub issues with issue numbers. BackdropFilter bugs have issue numbers. Some specifics (exact Riverpod 3 provider API edge cases) are MEDIUM. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Package version pinning:** Before writing code, run `flutter pub add` for each dependency and record the actual resolved versions. The researched versions need confirmation against current pub.dev before beginning Phase 1.
- **`watcher` package `isDirectory` assertion bug status:** Check dart-lang/watcher#79 to confirm if fixed in the current version. If still open, design a try/catch wrapper for directory events before Phase 3.
- **`Process.run()` M1 hang (Flutter issue #95805):** Confirm if resolved in Flutter 3.29. If not, add timeout wrappers to ALL subprocess calls from day one — not just git calls. This applies to `open -a Terminal` quick actions as well.
- **OKLCH design tokens:** Before Phase 4, convert all OKLCH color values from the n3urala1 design system to sRGB hex using oklch.com. Create a single `color_tokens.dart` constants file. Design-time task, not a code task.
- **`lucide_icons` Flutter package coverage:** The web v1.0 uses Lucide icons. The `lucide_icons` Flutter package exists but icon coverage may differ from the web version. Verify which icons are used in v1.0 before Phase 4.

---

## Sources

### Primary (HIGH confidence)
- Flutter macOS building docs: https://docs.flutter.dev/platform-integration/macos/building — sandbox, entitlements, deployment targets
- Flutter isolates docs: https://docs.flutter.dev/perf/isolates — background isolate patterns
- Dart isolates language reference: https://dart.dev/language/isolates — `Isolate.run()` API
- v1.0 source code (direct read): `components/codeProjectCard.tsx`, `researchProjectCard.tsx`, `toolsPanel.tsx`, `projectTabs.tsx`, `lib/scanner.ts`, `lib/watcher.ts`, `lib/git-reader.ts`, `app/actions.ts`, `app/page.tsx` — feature inventory

### Secondary (MEDIUM confidence)
- pub.dev/packages/tray_manager — tray_manager 0.5.0, updated November 2025
- pub.dev/packages/window_manager — updated October 2025, leanflutter
- pub.dev/packages/watcher — Dart team maintained, ~January 2026, 10.5M downloads
- pub.dev/packages/flutter_riverpod — ^3.2.1, Riverpod 3.x series
- riverpod.dev/docs/whats_new — Riverpod 3.0 changes
- codewithandrea.com — Flutter Riverpod AsyncNotifier and architecture patterns
- Flutter macOS menubar template: https://github.com/mynameiskenlee/flutter_macos_menubar_example
- Flutter issue #95805 — Process hangs on M1 debug mode
- Dart SDK issue #38364 — PATH not resolved for Process on macOS
- Flutter issue #66920 — FileSystemException sandbox
- Flutter issue #173530 — BackdropFilter white halo on dark backgrounds
- Flutter issues #149368, #143947, #126353 — Impeller BackdropFilter performance
- dart-lang/watcher issue #79 — isDirectory assertion failure on macOS
- dart-lang/sdk issue #62124 — macOS watcher omits directory create events

### Tertiary (LOW confidence)
- pub.dev/packages/oklch — v0.0.2, niche package; prefer manual OKLCH→sRGB conversion at design time
- dasroot.net/posts/2026/02/flutter-desktop-applications — Flutter Desktop 2026 overview (third-party)

---
*Research completed: 2026-02-19*
*Ready for roadmap: yes*
