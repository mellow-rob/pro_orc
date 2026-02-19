# Feature Research

**Domain:** Flutter macOS Desktop Dashboard (Pro Orc v1.1 rewrite)
**Researched:** 2026-02-19
**Confidence:** HIGH (Flutter macOS APIs verified via official docs and pub.dev; v1.0 feature inventory read directly from source code)

---

## v1.0 Feature Inventory (Full Source Read — Complete Baseline)

Every feature that exists in the current Next.js app, sourced from direct code reading:

| v1.0 Feature | Source File | Notes |
|---|---|---|
| Card-grid dashboard with GSD status, phase progress, next step | `components/codeProjectCard.tsx` | Progress bar, phases/plans counters, stale badge (>30 days amber), private toggle |
| Auto-scan of `~/code/` and `~/project research/` directories | `lib/scanner.ts` | Reads `.planning/` YAML, CLAUDE.md description fallback |
| Type detection (code vs research projects) | `lib/types.ts` + `lib/scanner.ts` | Code projects get git enrichment; research projects do not |
| Live updates via chokidar + SSE | `lib/watcher.ts` | Watches `.planning/` files only; debounced 300ms per project |
| Git integration (last commit message, timestamp) | `lib/git-reader.ts` | `git log` subprocess; enriched per code project |
| Quick actions: Terminal.app, Finder, GitHub, Notion | `app/actions.ts` | `open -a Terminal`, `open <path>`, `open <url>` shell commands |
| Research project cards (separate fuchsia accent layout) | `components/researchProjectCard.tsx` | Subset of code card — no git section, accent color differs |
| Tab navigation (Code / Research / Claude Tools) | `components/projectTabs.tsx` | Three-tab layout with project counts |
| Claude Tools inventory (Skills, MCP servers, Plugins) | `components/toolsPanel.tsx` + `lib/tools-scanner.ts` | Reads `~/.claude/` directory; three category sections |
| Private/visible toggle per card | `codeProjectCard.tsx` | Eye/EyeOff icon; opacity-60 when private; state is client-only (no persistence) |
| n3urala1 dark theme | `app/globals.css` | Cyan primary, fuchsia accent, glow box-shadows, atmospheric orbs |
| Atmospheric background orbs | `app/page.tsx` | CSS radial gradient blobs positioned top-left (cyan) and bottom-right (fuchsia) |
| Stale project detection | `codeProjectCard.tsx` `isStale()` | >30 days since last commit; amber border + "Stale" badge |
| Relative time formatting | `codeProjectCard.tsx` `formatRelativeTime()` | "2 days ago", "just now" etc. |
| Description from CLAUDE.md fallback | `lib/scanner.ts` | If .planning/ has no description, parse CLAUDE.md |

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features the single user (the developer themselves) will notice immediately if missing. This is a personal tool — missing any of these makes the app non-functional.

| Feature | Why Expected | Complexity | Flutter macOS Approach | Dependencies |
|---|---|---|---|---|
| Card grid — code projects | Core value; identical output to v1.0 with all data fields | MEDIUM | `GridView.builder` + custom card widgets. `SliverGridDelegateWithMaxCrossAxisExtent` for responsive columns. | Theme system |
| Card grid — research projects | Separate layout with fuchsia accent color | LOW | Same `GridView`, different card widget variant; color comes from theme | Card grid core |
| Tab navigation (Code / Research / Tools) | Three content areas; identical to v1.0 | LOW | Built-in Flutter `TabBar` + `TabBarView` | None |
| Directory scanner (`~/code/` and `~/project research/`) | Without this, no data — app is empty | MEDIUM | `dart:io` `Directory(path).list()` — direct replacement for `fs.readdir()`. No plugin needed. | File system entitlements |
| .planning/ YAML parser | GSD status, phase progress, next step all come from here | MEDIUM | `yaml` pub.dev package. Pure Dart port of `lib/parser.ts`. | Directory scanner |
| Git data (last commit message + timestamp) | Shown on every code card; core data point | MEDIUM | `dart:io` `Process.run('git', ['log', '--format=%H|%s|%ci', '-1'])` — direct equivalent of `child_process.exec('git log')` | Directory scanner, process access entitlements |
| File system watcher with debounce | Live refresh when `.planning/` files change | MEDIUM | `watcher` pub.dev package (exact chokidar equivalent: `DirectoryWatcher`). Debounce via `Timer`. Emits to `StreamController.broadcast()`. | Directory scanner |
| Quick action: Open in Terminal.app | Used constantly; critical for developer workflow | LOW | `Process.run('open', ['-a', 'Terminal', path])` — identical shell command to v1.0 | `dart:io` process access |
| Quick action: Open in Finder | One-click project folder access | LOW | `Process.run('open', [path])` — identical to v1.0 | `dart:io` process access |
| Quick action: Open GitHub URL | Opens repo in browser | LOW | `url_launcher` package `launchUrl(Uri.parse(url))` | None |
| Quick action: Open Notion URL | Opens Notion page in browser | LOW | `url_launcher` package `launchUrl(Uri.parse(url))` | None |
| Claude Tools panel (Skills, MCP, Plugins) | v1.0 feature; must port | MEDIUM | Dart file I/O to read `~/.claude/` — direct port of `lib/tools-scanner.ts` | File system entitlements |
| n3urala1 dark theme | Visual identity — cyan primary, fuchsia accent, glow effects, atmospheric orbs | MEDIUM | Flutter `ThemeData` + custom `ColorScheme`. Orbs via `Stack` + `Container` with `BoxDecoration(gradient: RadialGradient(...))`. `BoxShadow` for glow on hover. Forced dark — `themeMode: ThemeMode.dark`. | Must be built before all UI components |
| Private/visible toggle per card | Hides sensitive projects; client-only state | LOW | `StatefulWidget` or Riverpod state. No persistence (matches v1.0 behavior). | None |
| Stale project detection (>30 days) | Amber border + badge for inactive projects | LOW | `DateTime.now().difference(lastCommit).inDays > 30` — trivial Dart port | Git data |
| Relative time formatting | "2 days ago", "just now" on last commit | LOW | `timeago` pub.dev package or direct Dart `Duration` port of `formatRelativeTime()` | None |
| Description from CLAUDE.md fallback | Shows project purpose when .planning/ has none | LOW | Dart `File.readAsString()` + regex on CLAUDE.md | Directory scanner |

### Differentiators (Native macOS — Not Available in Web v1.0)

Features unlocked by going native. These are the primary reason for the rewrite.

| Feature | Value Proposition | Complexity | Flutter macOS Approach | Package |
|---|---|---|---|---|
| Menubar tray icon (always-on-screen access) | App accessible without a browser tab; feels like a real macOS citizen. Primary native differentiator. | HIGH | `tray_manager` pub.dev — sets `NSStatusItem` icon + context menu. Show/hide main window from tray. | `tray_manager` |
| Main window show/hide from menubar click | Click tray icon to toggle the dashboard window; instant access | MEDIUM | `window_manager` package `windowManager.show()` / `windowManager.hide()` combined with `tray_manager` click handler | `window_manager`, `tray_manager` |
| Window position and size persistence | Native app remembers where you left it; web app has no window concept | LOW | `window_manager` `getPosition()`/`getSize()` + `shared_preferences` to persist on close | `window_manager`, `shared_preferences` |
| No browser or server required | App runs as a standalone `.app`; no `npm run dev`, no localhost, no terminal needed to start it | HIGH | Core native benefit — the entire point of the rewrite. Dart compiles to native binary. | N/A |
| macOS native menu bar (app menu) | File/Edit/View menus; Cmd+C/V/Z work out of the box everywhere | LOW | Flutter built-in `PlatformMenuBar` widget. No plugin needed. | Built-in Flutter 3.x+ |
| Global keyboard shortcut (show/hide window) | Cmd+Shift+P or similar to surface dashboard from any app without clicking the menubar | MEDIUM | `hotkey_manager` pub.dev supports system-wide hotkeys on macOS | `hotkey_manager` |
| Faster startup than Electron/web | Native Impeller rendering; no Chrome subprocess; no Node.js cold start | MEDIUM | Flutter Impeller renderer (stable in Flutter 3.38+); ~40% lower CPU vs Skia. Binary startup measured in hundreds of milliseconds. | Built-in Flutter |
| macOS notifications for stale projects | Proactive alert when a project hasn't been touched in 30+ days | MEDIUM | `flutter_local_notifications` package; requires `com.apple.security.user-notifications` entitlement | `flutter_local_notifications` |
| Dock icon presence | App visible in Dock + Cmd+Tab app switcher | LOW | Default Flutter macOS behavior. Suppress for menubar-only mode via `LSUIElement = YES` in `Info.plist`. | None (Info.plist) |
| macos_ui native widgets (optional) | Toolbars, popovers, sidebars match macOS Human Interface Guidelines | MEDIUM | `macos_ui` package (requires Flutter 3.35+). Provides `MacosWindow`, `MacosToolbar`. Optional — custom n3urala1 theme may be preferred over HIG compliance. | `macos_ui` (optional) |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---|---|---|---|
| App Store distribution | "Make it a real Mac app" | macOS sandbox blocks reads to arbitrary user directories (`~/code/`, `~/project research/`). Requires `com.apple.security.files.all` or Powerbox bookmarks API — significant complexity for a personal tool. | Distribute as a signed, notarized `.app` outside the App Store. Disable sandbox in entitlements (`com.apple.security.app-sandbox = false`). |
| Light mode support | "macOS users expect system theme" | The n3urala1 aesthetic is intentionally dark. Building a full parallel light color system doubles CSS/theme surface area for zero user demand. This is a personal single-developer tool. | Lock to `themeMode: ThemeMode.dark`. |
| SSE / HTTP server inside the Flutter app | Port the exact web architecture | Flutter desktop apps don't need an HTTP server. The watcher and UI are in the same Dart process. SSE was required because Next.js is client/server split. | `dart:io` `DirectoryWatcher` → `StreamController.broadcast()` → `StreamBuilder` in widgets. Direct same-process pub/sub. |
| Multi-window (one window per project) | "Click card to open detail window" | `desktop_multi_window` adds significant complexity. No detail view exists in v1.0 — don't invent one during a port rewrite. | Single window; if detail view is needed later, use a side panel or `Navigator` push within the same window. |
| WebView for rendering READMEs | "Show project docs inline" | `webview_flutter` on macOS requires extra entitlements and adds 30+ MB to binary. Not a v1.0 feature. | Use `flutter_markdown` if lightweight inline markdown is ever needed. |
| Auto-update mechanism | "Push updates without reinstalling" | Requires Sparkle integration or App Store — both are complex. Single-developer personal tool. | `git pull && flutter build macos` is the update mechanism. |
| Cloud sync of project state | "Access dashboard from another Mac" | The entire value is reading the local filesystem. Remote sync breaks the single-purpose design and adds auth/networking complexity. | Not applicable — stay local-only. |
| iTerm2 / Warp / Ghostty terminal support | Multiple terminal options | Requires terminal detection logic and fallback handling. Multiple edge cases. | Terminal.app only via `open -a Terminal path`. Make configurable in v2 if needed. |

---

## Feature Dependencies

```
[File System Entitlements in Runner.entitlements]
    └──required by──> [Directory Scanner]
    └──required by──> [Git Data Reader]
    └──required by──> [Claude Tools Scanner]

[Directory Scanner]
    └──produces──> [Code Project List]
    └──produces──> [Research Project List]
    └──drives──> [File System Watcher] (what to watch)

[Code Project List]
    └──requires──> [.planning/ YAML Parser]
    └──enhanced by──> [Git Data Reader]
    └──drives──> [Code Card Grid]

[Research Project List]
    └──requires──> [.planning/ YAML Parser]
    └──drives──> [Research Card Grid]

[File System Watcher]
    └──requires──> [Directory Scanner]
    └──emits to──> [StreamController.broadcast()]
    └──drives──> [StreamBuilder auto-refresh in all card grids]

[Git Data Reader]
    └──requires──> [dart:io Process.run access]
    └──requires──> [File system entitlements]

[Menubar Tray Icon]
    └──requires──> [tray_manager package]
    └──requires──> [window_manager package]
    └──enhanced by──> [Global Keyboard Shortcut]

[Global Keyboard Shortcut]
    └──requires──> [hotkey_manager package]
    └──requires──> [window_manager package]

[Claude Tools Panel]
    └──requires──> [~/.claude/ read access via entitlements]

[n3urala1 Dark Theme]
    └──required by──> [ALL UI components]
    └──must be established in Phase 1 before any card widgets]
```

### Dependency Notes

- **Entitlements are a gate, not a detail** — the macOS sandbox will silently deny file system reads outside the app container. Configure `DebugProfile.entitlements` and `Release.entitlements` in the first phase before any scanner work, or all scanner tests will silently return empty results.
- **SSE architecture does not port — use StreamController instead** — in Flutter, the watcher and the UI are in the same Dart process. `StreamController.broadcast()` is the direct, simpler replacement for the Next.js SSE + chokidar architecture. `StreamBuilder` widgets subscribe to the stream directly.
- **window_manager must initialize in `main()` before `runApp()`** — call `await windowManager.ensureInitialized()` before the widget tree starts.
- **tray_manager requires window_manager** for the show/hide window pattern. Both packages are from leanflutter and are designed to work together.
- **n3urala1 theme tokens must be defined before any UI components** — all cards reference theme colors; build the color system in the first phase.

---

## MVP Definition

This is a **rewrite for feature parity + one native differentiator**, not a new product. MVP = "every v1.0 feature works natively as a menubar app."

### Launch With (v1.1 — Feature Parity + Menubar)

- [ ] Card grid — code projects with all data fields (name, status, progress, next step, git commit, stale badge, private toggle)
- [ ] Card grid — research projects with fuchsia accent layout
- [ ] Tab navigation (Code / Research / Claude Tools)
- [ ] Directory scanner reading `~/code/` and `~/project research/`
- [ ] .planning/ YAML parser (GSD status, phase/plan counts, next step, description)
- [ ] Git data reader (last commit message + timestamp)
- [ ] File system watcher with debounced auto-refresh via StreamController
- [ ] Quick actions: Terminal.app, Finder, GitHub URL, Notion URL
- [ ] Claude Tools panel (Skills, MCP, Plugins from `~/.claude/`)
- [ ] n3urala1 dark theme (cyan/fuchsia color system, orbs, glow)
- [ ] Menubar tray icon with show/hide main window — **the primary native differentiator**
- [ ] Window position/size persistence

### Add After Validation (v1.1.x)

- [ ] Global keyboard shortcut (show/hide) — add once window behavior is stable
- [ ] macOS native menu bar (app menu with Cmd+C/Q etc.) — low cost polish
- [ ] macOS notifications for stale projects — add once core data pipeline is solid

### Future Consideration (v1.2+)

- [ ] Inline markdown rendering for project descriptions (`flutter_markdown`)
- [ ] Search/filter across projects by name
- [ ] Configurable terminal app (iTerm2, Warp, Ghostty)
- [ ] Dock badge showing count of stale or active GSD projects
- [ ] Project detail side panel

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| n3urala1 dark theme | HIGH | MEDIUM | P1 — build first, all widgets depend on it |
| Directory scanner + YAML parser | HIGH | MEDIUM | P1 |
| Git data reader | HIGH | LOW | P1 |
| Card grid (code + research) | HIGH | MEDIUM | P1 |
| File system watcher + auto-refresh | HIGH | MEDIUM | P1 |
| Quick actions (Terminal, Finder, URLs) | HIGH | LOW | P1 |
| Tab navigation | HIGH | LOW | P1 |
| Menubar tray icon + window show/hide | HIGH | HIGH | P1 — primary native differentiator |
| Window manager (persist bounds) | MEDIUM | LOW | P1 |
| Claude Tools panel | MEDIUM | MEDIUM | P1 |
| Private/visible toggle | MEDIUM | LOW | P2 |
| macOS native menu bar | LOW | LOW | P2 |
| Global hotkey (show/hide) | MEDIUM | MEDIUM | P2 |
| macOS notifications | LOW | MEDIUM | P3 |
| Markdown rendering | LOW | LOW | P3 |
| Search/filter | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for v1.1 launch
- P2: Should have, add in v1.1.x iteration
- P3: Nice to have, future consideration

---

## Web-to-Native Feature Mapping

Direct translation from v1.0 implementation to Flutter macOS equivalent:

| v1.0 (Next.js) | Flutter macOS Equivalent | Confidence | Notes |
|---|---|---|---|
| `chokidar.watch()` | `watcher` pub.dev `DirectoryWatcher` | HIGH | Nearly identical API; `watcher` is the Dart-native chokidar |
| `globalThis.__watcherSubscribers` (SSE broadcast) | `StreamController<ProjectEvent>.broadcast()` | HIGH | Same pub/sub; no HTTP server needed |
| `EventSource` in browser client | `StreamBuilder` widget | HIGH | Direct in-process subscription; no network hop |
| `fs.readdir()` | `dart:io` `Directory(path).list()` | HIGH | Direct equivalent |
| `child_process.exec('git log')` | `dart:io` `Process.run('git', ['log', ...])` or `process_run` package | HIGH | Identical shell invocation |
| `open -a Terminal path` | `Process.run('open', ['-a', 'Terminal', path])` | HIGH | Same macOS shell command |
| `open path` (Finder) | `Process.run('open', [path])` | HIGH | Same macOS shell command |
| `open https://...` (URL) | `url_launcher` `launchUrl(Uri.parse(url))` | HIGH | Standard Flutter approach |
| React `useState` (private toggle) | `StatefulWidget` bool or Riverpod `StateProvider` | HIGH | Standard Flutter state |
| Next.js `useTransition` (pending state) | `StatefulWidget` bool `_isLoading` + `setState` | HIGH | Simple Dart async pattern |
| Tailwind `grid` responsive columns | `GridView.builder` + `SliverGridDelegateWithMaxCrossAxisExtent` | HIGH | `maxCrossAxisExtent: 320` gives similar responsive behavior |
| Tailwind `backdrop-blur-sm` | `BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4))` | HIGH | Requires `ClipRect` wrapper |
| CSS `glow-cyan` `box-shadow` | `BoxDecoration(boxShadow: [BoxShadow(color: cyan.withOpacity(0.3), blurRadius: 20)])` | HIGH | Direct equivalent |
| CSS background orbs (radial gradients) | `Stack` + `Positioned` + `Container(decoration: BoxDecoration(gradient: RadialGradient(...)))` with `IgnorePointer` | HIGH | Same visual result |
| Lucide icons (`Terminal`, `Folder`, `Clock`, etc.) | `lucide_icons` pub.dev package | MEDIUM | Package exists; verify current icon coverage before committing |
| YAML parsing (`parseGsdData`) | `yaml` pub.dev `loadYaml()` | HIGH | Standard Dart YAML library |
| Next.js Server Actions (no-op in Flutter) | Not needed | HIGH | All logic is local Dart; no client/server split |

---

## macOS Sandbox — Critical Configuration

**This is the #1 cause of silent failures in Flutter macOS apps.** The sandbox blocks all file system reads outside the app container by default.

Required in both `macos/Runner/DebugProfile.entitlements` AND `macos/Runner/Release.entitlements`:

```xml
<!-- Required: run subprocesses (git, open) -->
<key>com.apple.security.app-sandbox</key>
<false/>
```

**Recommendation for Pro Orc:** Disable the sandbox entirely. This is a personal developer tool distributed outside the App Store. It needs unrestricted access to `~/code/`, `~/project research/`, `~/.claude/`, and the ability to run `git` and `open` as subprocesses. The sandbox provides no meaningful security benefit for a tool that only runs as the owner.

Alternatively, if sandbox must remain enabled, the minimum required entitlements are:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<!-- Read access to user-selected locations -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<!-- Allow running child processes (git, open) -->
<key>com.apple.security.inherit</key>
<true/>
```

Confidence: MEDIUM — specific entitlement combinations need testing. The sandbox + subprocess interaction is a known Flutter macOS pain point (multiple open GitHub issues).

---

## Sources

- [Flutter macOS building docs — sandbox and entitlements](https://docs.flutter.dev/platform-integration/macos/building) (HIGH confidence — official)
- [tray_manager pub.dev](https://pub.dev/packages/tray_manager) (HIGH confidence — official package page)
- [window_manager GitHub — leanflutter](https://github.com/leanflutter/window_manager) (HIGH confidence — official repo)
- [hotkey_manager GitHub — leanflutter](https://github.com/leanflutter/hotkey_manager) (HIGH confidence — official repo)
- [watcher pub.dev](https://pub.dev/packages/watcher) (HIGH confidence — official package page)
- [url_launcher pub.dev](https://pub.dev/packages/url_launcher) (HIGH confidence — official Flutter team package)
- [flutter_local_notifications pub.dev](https://pub.dev/packages/flutter_local_notifications) (HIGH confidence — official package page)
- [macos_ui pub.dev](https://pub.dev/packages/macos_ui) (HIGH confidence — official package page)
- [Flutter Actions and Shortcuts docs](https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts) (HIGH confidence — official)
- [Flutter Desktop 2026 overview](https://dasroot.net/posts/2026/02/flutter-desktop-applications-windows-macos-linux/) (MEDIUM confidence — third-party, recent)
- v1.0 source code — read directly from: `pro-orc/components/codeProjectCard.tsx`, `researchProjectCard.tsx`, `toolsPanel.tsx`, `projectTabs.tsx`, `lib/scanner.ts`, `lib/watcher.ts`, `lib/git-reader.ts`, `app/actions.ts`, `app/page.tsx` (HIGH confidence — primary source)

---
*Feature research for: Flutter macOS desktop dashboard rewrite (Pro Orc v1.1)*
*Researched: 2026-02-19*
