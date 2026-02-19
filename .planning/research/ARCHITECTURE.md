# Architecture Research

**Domain:** Flutter macOS desktop dashboard — local filesystem + git metadata, menubar + main window
**Researched:** 2026-02-19
**Confidence:** MEDIUM-HIGH (WebSearch verified; some package versions unconfirmed without direct pub.dev fetch)

---

## Context: v1.0 → v1.1 Layer Mapping

The existing Next.js v1.0 has five backend "lib" modules. Each maps directly to a Dart equivalent.

The critical architectural insight: the Next.js server/client boundary disappears entirely. The Flutter app IS both sides — Dart services read the filesystem directly, Riverpod streams replace SSE, widgets replace React components. There is no HTTP layer between scanner and UI.

| Next.js v1.0 Layer | Responsibility | Dart/Flutter Equivalent |
|--------------------|---------------|------------------------|
| `lib/scanner.ts` | Walk `code/` + `project research/` dirs, return project list | `ProjectScannerService` (dart:io `Directory.list()`) |
| `lib/parser.ts` | Parse `.planning/STATE.md`, `ROADMAP.md`, `PROJECT.md` | `GsdParser` (dart:io `File.readAsString()` + RegExp) |
| `lib/git-reader.ts` | `git log`, `git status` via simple-git | `GitReaderService` (dart:io `Process.run('git', ...)`) |
| `lib/watcher.ts` | chokidar singleton for filesystem events | `WatcherService` (Dart `watcher` package, `DirectoryWatcher`) |
| `lib/tools-scanner.ts` | Walk `~/.claude/` for Skills/MCP/Plugins | `ToolsScannerService` (dart:io `Directory.list()`) |
| SSE route handler | Push events to browser over HTTP | Riverpod `StreamProvider` — in-process, no HTTP at all |
| React hooks (`usePrivateProjects`, `useProjectEvents`) | Client state + live updates | Riverpod `ref.watch()` on AsyncNotifier providers |

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  MenuBarApp  │  │  MainWindow  │  │  ToolsPanel  │              │
│  │  (tray icon) │  │  (card grid) │  │  (claude inv)│              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                  │                      │
│  ┌──────▼─────────────────▼──────────────────▼───────────────────┐  │
│  │                    Riverpod Providers                          │  │
│  │  projectsProvider   watcherProvider   toolsProvider           │  │
│  └──────┬──────────────────┬─────────────────┬────────────────────┘  │
├─────────┼──────────────────┼─────────────────┼─────────────────────┤
│                        SERVICE LAYER                                │
│  ┌──────▼───────┐   ┌──────▼───────┐   ┌──────▼───────┐            │
│  │  ProjectScanner  │  WatcherSvc  │   │  ToolsScanner│            │
│  │  GsdParser   │   │  (watcher   │   │              │            │
│  │  GitReader   │   │   package)  │   │              │            │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘            │
├─────────┼──────────────────┼─────────────────┼─────────────────────┤
│                   BACKGROUND ISOLATE (optional)                     │
│  ┌──────▼────────────────────────────────────────────────────────┐  │
│  │  Isolate.run() — git subprocess calls on initial scan        │  │
│  │  ReceivePort/SendPort communication back to main isolate     │  │
│  └───────────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│                  PLATFORM LAYER (macOS native)                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │  tray_manager   │  │  dart:io        │  │  Process.run    │     │
│  │  (NSStatusItem) │  │  (filesystem)   │  │  (git CLI)      │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|---------------|----------------|
| `MenuBarApp` | Tray icon, click to show/hide main window | `tray_manager` package + NSStatusItem |
| `MainWindow` | Full dashboard, project card grid layout | Flutter `MaterialApp`, custom window chrome |
| `ProjectCard` | Single code project display | Stateless widget, receives `CodeProject` model |
| `ResearchCard` | Research project variant (no git section) | Stateless widget, receives `ResearchProject` model |
| `ToolsPanel` | Claude tools inventory sidebar | Riverpod-fed list of `ClaudeTool` models |
| `projectsProvider` | Async stream of all discovered projects | Riverpod `AsyncNotifierProvider<List<Project>>` |
| `watcherProvider` | Filesystem change events (stays alive) | Riverpod `StreamProvider<WatchEvent>` with `ref.keepAlive()` |
| `toolsProvider` | Claude tools list (static, loaded once) | Riverpod `FutureProvider<List<ClaudeTool>>` |
| `ProjectScannerService` | Walk `code/` and `project research/` | `dart:io Directory.list(recursive: true)` |
| `GsdParser` | Parse `.planning/STATE.md`, `ROADMAP.md`, `PROJECT.md` | `dart:io File.readAsString()` + `RegExp` |
| `GitReaderService` | Extract branch, last commit SHA, message, timestamp | `dart:io Process.run('git', ['log', ...])` |
| `WatcherService` | Watch scan paths, emit change events | Dart `watcher` package `DirectoryWatcher` |
| `ToolsScannerService` | Walk `~/.claude/` for Skills/MCP/Plugins | `dart:io Directory.list()` + JSON/YAML parsing |

---

## Recommended Project Structure

```
lib/
├── main.dart                      # App entry: init tray, window, ProviderScope
├── app.dart                       # Root MaterialApp widget
│
├── models/                        # Pure Dart — no Flutter imports, usable in isolates
│   ├── project.dart               # Project (sealed class), CodeProject, ResearchProject
│   ├── gsd_state.dart             # GsdPhase, NextStep, RoadmapProgress
│   ├── git_info.dart              # GitInfo (branch, lastCommit, sha, timestamp)
│   └── claude_tool.dart           # ClaudeTool (name, type: skill/mcp/plugin, description)
│
├── services/                      # Pure Dart business logic — no Riverpod, no Flutter
│   ├── project_scanner.dart       # Directory walk → List<Project>
│   ├── gsd_parser.dart            # File read + regex → GsdState per project
│   ├── git_reader.dart            # Process.run git → GitInfo
│   ├── watcher_service.dart       # DirectoryWatcher → Stream<WatchEvent>
│   └── tools_scanner.dart         # ~/.claude/ walk → List<ClaudeTool>
│
├── providers/                     # Riverpod — wires services into widget tree
│   ├── projects_provider.dart     # AsyncNotifierProvider<List<Project>>
│   ├── watcher_provider.dart      # StreamProvider<WatchEvent>
│   └── tools_provider.dart        # FutureProvider<List<ClaudeTool>>
│
├── ui/
│   ├── windows/
│   │   └── main_window.dart       # Dashboard window layout + card grid
│   ├── widgets/
│   │   ├── project_card.dart      # Code project card
│   │   ├── research_card.dart     # Research project card (no git section)
│   │   ├── tools_panel.dart       # Claude tools inventory
│   │   ├── phase_badge.dart       # GSD phase visual indicator (pill/chip)
│   │   ├── git_info_row.dart      # Branch + last commit + relative timestamp
│   │   └── quick_actions.dart     # Terminal / Finder / Notion buttons
│   └── theme/
│       └── app_theme.dart         # Dark theme, macOS-native typography + spacing
│
├── platform/                      # macOS-specific integration
│   ├── tray.dart                  # tray_manager setup + click handler
│   └── window_manager.dart        # Window show/hide/position helpers
│
└── isolates/
    └── git_worker.dart            # Isolate.run() wrapper for concurrent git calls
```

### Structure Rationale

- **`models/`:** No Flutter imports. This enables models to be used inside `Isolate.run()` without pulling in Flutter bindings. Sealed class `Project` forces exhaustive handling of `CodeProject` vs `ResearchProject` in the UI.
- **`services/`:** No Riverpod dependency. Services are plain Dart classes, trivially unit-testable. Riverpod providers instantiate them — services never reach up into providers.
- **`providers/`:** Thin wiring layer. Providers hold no business logic; they instantiate services and expose reactive state. A provider that is 20 lines is correct; 100 lines means logic leaked from services.
- **`ui/`:** Pure Flutter. Widgets get all data via `ref.watch()`. No widget imports a service directly.
- **`platform/`:** macOS-specific code lives here, not in services or UI. Makes it easy to find all native integration points and keeps the rest of the codebase portable.
- **`isolates/`:** Background work is explicit and contained. Only git subprocess calls go here on initial load.

---

## Architectural Patterns

### Pattern 1: Riverpod AsyncNotifier for Projects

**What:** Projects load asynchronously at startup; the notifier subscribes to the watcher stream and invalidates itself on any filesystem change.

**When to use:** Any state with both async initialization AND live-update triggers.

**Trade-offs:** Slightly more code than `FutureProvider`, but the `ref.listen`-based invalidation pattern is the correct way to wire a watcher event into a re-scan. A plain `FutureProvider` cannot respond to external events.

**Example:**
```dart
// providers/projects_provider.dart
@riverpod
class Projects extends _$Projects {
  @override
  Future<List<Project>> build() async {
    // Re-scan whenever the watcher fires any event
    ref.listen(watcherProvider, (prev, next) {
      ref.invalidateSelf();
    });

    final scanner = ProjectScannerService();
    final projects = await scanner.scan();

    // Enrich code projects with git info (runs concurrently)
    return Future.wait(
      projects.map((p) => _enrichWithGit(p)),
    );
  }

  Future<Project> _enrichWithGit(Project p) async {
    if (p is! CodeProject) return p;
    final gitInfo = await gitWorker.fetchGitInfo(p.path);
    return p.copyWith(gitInfo: gitInfo);
  }
}
```

### Pattern 2: StreamProvider with keepAlive for Filesystem Watcher

**What:** `WatcherService` exposes a `Stream<WatchEvent>`. The provider wraps it and must stay alive permanently so the watcher never stops even when no widget is actively observing it.

**When to use:** Any persistent event source that must run for the app lifetime.

**Trade-offs:** `ref.keepAlive()` is required and non-obvious. Without it, Riverpod disposes the stream when the last subscriber unmounts (e.g., during window hide), which kills the watcher silently.

**Example:**
```dart
// providers/watcher_provider.dart
@riverpod
Stream<WatchEvent> watcher(WatcherRef ref) {
  ref.keepAlive();  // Never dispose — watcher must outlive any single widget

  final home = Platform.environment['HOME'] ?? '';
  final service = WatcherService(paths: [
    '$home/project_orchestration/code',
    '$home/project_orchestration/project research',
  ]);

  return service.events;
}

// services/watcher_service.dart
class WatcherService {
  final List<String> paths;
  WatcherService({required this.paths});

  Stream<WatchEvent> get events {
    // Merge streams from all watched directories
    final streams = paths.map((p) {
      return DirectoryWatcher(p).events.map(
        (e) => WatchEvent(path: e.path, type: e.type.toString()),
      );
    });
    return StreamGroup.merge(streams.toList());
  }
}
```

**Note:** The Dart `watcher` package uses FSEvents on macOS natively — the same underlying mechanism as Node.js chokidar. It is the direct Dart equivalent of `lib/watcher.ts`. Use `async` package's `StreamGroup.merge()` to combine multiple directory watchers into one stream.

### Pattern 3: Background Isolate for Git Subprocesses

**What:** Git subprocess calls block while the OS spawns the process and waits for output. With 20+ projects, sequential calls cause multi-second UI freezes on startup. `Isolate.run()` offloads these to a background isolate.

**When to use:** During the initial project scan enrichment pass. For single watcher-triggered re-scans (one project at a time), the blocking cost (~100ms) is acceptable on the main isolate.

**Trade-offs:** `Isolate.run()` is simple and clean but creates a new isolate per call. For the initial scan, batch calls via `Future.wait` with a concurrency cap rather than one-isolate-per-project.

**Example:**
```dart
// isolates/git_worker.dart
Future<GitInfo?> fetchGitInfo(String projectPath) {
  return Isolate.run(() async {
    final result = await Process.run(
      'git',
      ['log', '-1', '--format=%H%n%s%n%ai'],
      workingDirectory: projectPath,
      runInShell: false,
    );
    if (result.exitCode != 0) return null;
    return GitInfo.parse(result.stdout as String);
  });
}

// In provider: concurrency-capped parallel enrichment
Future<List<Project>> _enrichAll(List<Project> projects) async {
  const maxConcurrent = 4;  // avoid spawning 50 isolates at once
  final results = <Project>[];

  for (final chunk in projects.slices(maxConcurrent)) {
    final enriched = await Future.wait(
      chunk.map((p) => _enrichWithGit(p)),
    );
    results.addAll(enriched);
  }
  return results;
}
```

### Pattern 4: Tray Icon + Main Window Lifecycle

**What:** App lives in the menubar. Main window starts hidden. Tray click shows/hides. `LSUIElement` in `Info.plist` suppresses the Dock icon.

**When to use:** Standard macOS menubar utility pattern.

**Trade-offs:** Requires `Info.plist` edit and `window_manager` setup. The macOS sandbox must be disabled or the window may not respond to tray clicks correctly in all configurations (open issue in `tray_manager` GitHub).

**Example:**
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 600),
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: true,
    ),
    () async {
      await windowManager.hide();  // start hidden; tray click reveals
    },
  );

  await _initTray();
  runApp(const ProviderScope(child: ProOrcApp()));
}

// platform/tray.dart
Future<void> initTray() async {
  await trayManager.setIcon('assets/tray_icon.png');
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(label: 'Show Dashboard', onClick: (_) => _showWindow()),
    MenuItem.separator(),
    MenuItem(label: 'Quit', onClick: (_) => exit(0)),
  ]));
  trayManager.addListener(_TrayListener());
}

class _TrayListener extends TrayListener {
  @override
  void onTrayIconMouseDown() => _showWindow();
}

void _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}
```

**Info.plist addition (required — hides Dock icon):**
```xml
<!-- macos/Runner/Info.plist -->
<key>LSUIElement</key>
<true/>
```

---

## Data Flow

### Startup Flow

```
main() called
  ├─ windowManager.ensureInitialized()
  ├─ window starts hidden (tray click needed to show)
  ├─ trayManager initialized — NSStatusItem appears in menubar
  └─ ProviderScope starts Flutter widget tree

  First widget observing projectsProvider triggers build():
  ├─ ref.listen(watcherProvider) registered — watcher starts (keepAlive)
  ├─ ProjectScannerService.scan() runs
  │   ├─ Directory.list('code/') → finds code projects
  │   └─ Directory.list('project research/') → finds research projects
  ├─ GsdParser.parse(path) per project → GsdState
  └─ GitReaderService (via Isolate.run) × code projects, max 4 concurrent
       └─ Process.run('git', ['log', '-1', ...])

  AsyncValue.data resolves → projectsProvider emits List<Project>
  → MainWindow renders card grid
```

### Live Update Flow (replaces SSE entirely)

```
User edits STATE.md / commits / adds a project directory
  ↓
dart:io FSEvents fires (via DirectoryWatcher in WatcherService)
  ↓
watcherProvider Stream<WatchEvent> emits new event
  ↓
ref.listen callback in projectsProvider fires
  ↓
ref.invalidateSelf() — projectsProvider transitions to AsyncValue.loading
  ↓
build() runs again: scan + parse + git enrichment
  ↓
projectsProvider emits new AsyncValue.data
  ↓
All widgets using ref.watch(projectsProvider) rebuild automatically
```

### Quick Action Flow

```
User clicks "Open in Terminal" on ProjectCard
  ↓
QuickActionsService.openInTerminal(project.path)
  ↓
Process.run('open', ['-a', 'Terminal', project.path])
  ↓
macOS opens Terminal.app cd'd to that directory
```

---

## macOS Sandbox Configuration

This is the single biggest implementation risk. Flutter macOS builds are sandboxed by default.

**What the sandbox blocks:**
- `dart:io File.readAsString()` for paths outside the app container (i.e., all project directories)
- `Process.run('git', ...)` — subprocess execution
- `DirectoryWatcher` for arbitrary filesystem paths

**Required entitlement changes — all three entitlement files:**
```xml
<!-- macos/Runner/DebugProfile.entitlements -->
<!-- macos/Runner/Release.entitlements -->
<key>com.apple.security.app-sandbox</key>
<false/>
```

**Alternative (App Store compatible, but far more complex):**
Use `NSOpenPanel` (user-selected file access) via a platform channel. This requires the user to explicitly grant folder access once. It is the correct approach for App Store distribution but introduces significant native code complexity unsuitable for a personal tool.

**Recommendation:** Disable sandbox entirely. This app is a personal developer tool, not distributed via App Store. The sandbox provides no value here and blocks all core functionality.

---

## Anti-Patterns

### Anti-Pattern 1: Calling Services Directly from Widgets

**What people do:** Import `ProjectScannerService` in a widget and call `scanner.scan()` in `build()` or `initState()`.

**Why it's wrong:** Bypasses Riverpod lifecycle. Results in duplicate work, no caching, no reactivity, and no error/loading state management. The scan runs on every rebuild.

**Do this instead:** Widgets call `ref.watch(projectsProvider)` and `ref.read(projectsProvider.notifier)`. Services are never imported into widget files.

### Anti-Pattern 2: Running Git Calls on the Main Isolate at Startup

**What people do:** Call `Process.run('git', [...])` sequentially in a provider's `build()` method without isolate offloading.

**Why it's wrong:** `Process.run` is `async` but the dart runtime still has to manage the subprocess. With 20+ projects, this creates visible jank during startup — the widget tree is blocked from painting while awaiting git calls.

**Do this instead:** Use `Isolate.run()` for the initial enrichment pass. Cap concurrency at 4 to avoid spawning 50 isolates simultaneously. For watcher-triggered single-project refreshes, the main isolate is fine.

### Anti-Pattern 3: Ignoring the Sandbox Early

**What people do:** Write all the dart:io and Process.run code, test it successfully in `flutter run` (which runs with reduced sandbox in debug mode), then discover it all fails in release mode.

**Why it's wrong:** Release builds enforce the full App Sandbox. `dart:io File` throws `FileSystemException: Cannot open file` on the first read of a project directory. `Process.run('git', ...)` fails with permission denied. This happens after significant implementation effort.

**Do this instead:** Disable the sandbox in ALL entitlement files from day one. Test a release build (`flutter build macos`) before writing any service logic. Make this a Phase 1 checklist item.

### Anti-Pattern 4: Multiple DirectoryWatcher Instances per Path

**What people do:** Create a new `WatcherService` on each provider rebuild or watch call.

**Why it's wrong:** Each `DirectoryWatcher` opens OS FSEvents handles. Recreation without prior disposal leaks handles and generates duplicate events. On macOS, the system limit for FSEvents streams is relatively low.

**Do this instead:** Use `ref.keepAlive()` to prevent the `watcherProvider` from ever being disposed. The watcher service should be instantiated once and persist for the application lifetime.

### Anti-Pattern 5: Encoding Window State in Widget Tree

**What people do:** Use `Navigator` or route changes to show/hide the dashboard window.

**Why it's wrong:** On macOS, window visibility is a native concept managed by AppKit, not Flutter's Navigator. Using Navigator hides the Flutter content but leaves the native window visible (or vice versa).

**Do this instead:** Use `window_manager.show()` and `window_manager.hide()` exclusively for window visibility. Flutter Navigator is for in-window routing only (if needed at all for this single-page app).

---

## Integration Points

### New vs Modified (v1.0 → v1.1)

| Component | Status | Notes |
|-----------|--------|-------|
| Scanner logic (path walk, depth, ignore patterns) | **Port** from `lib/scanner.ts` | Identical logic, different API: `Directory.list()` vs `fs.readdir()` |
| GSD parser (STATE.md, ROADMAP.md, PROJECT.md regex) | **Port** from `lib/parser.ts` | Same regex patterns; Dart `RegExp` API matches JS |
| Git reader (log format, timeout, non-fatal errors) | **Port** from `lib/git-reader.ts` | `Process.run` instead of simple-git; same `git log -1 --format=` pattern |
| Watcher (directory watch, event types) | **Replace** `lib/watcher.ts` | `watcher` package `DirectoryWatcher` replaces chokidar; no singleton guard needed (Riverpod handles lifecycle) |
| Tools scanner (`~/.claude/` walk) | **Port** from `lib/tools-scanner.ts` | Same JSON/YAML parsing, different I/O API |
| SSE → Riverpod providers | **New pattern** | SSE network layer replaced by in-process streams; no HTTP at all |
| React components → Flutter widgets | **Rewrite** | `ProjectCard`, `ResearchCard`, `ToolsPanel`, `PhaseBadge`, `GitInfoRow` |
| menubar / tray | **New** | Did not exist in v1.0; `tray_manager` + `window_manager` + `Info.plist` |
| Quick actions (Terminal, Finder, Notion) | **Port** | Same shell commands (`open -a Terminal`, `open`, `open <url>`); `Process.run` instead of Node.js `child_process` |

### External Dependencies (macOS Platform)

| Native Concern | Flutter/Dart Bridge | Package |
|---------------|---------------------|---------|
| Tray icon click → show window | `TrayListener.onTrayIconMouseDown` | `tray_manager` |
| Window show/hide/resize | `windowManager.show()` / `.hide()` | `window_manager` |
| Filesystem events | `DirectoryWatcher(path).events` | `watcher` |
| Git subprocess | `dart:io Process.run('git', args, workingDirectory: path)` | Built-in (`dart:io`) |
| Open Terminal.app | `Process.run('open', ['-a', 'Terminal', path])` | Built-in |
| Open Finder | `Process.run('open', [path])` | Built-in |
| Open Notion URL | `Process.run('open', [notionUrl])` | Built-in |

---

## Build Order (Phase Dependencies)

Phase sequencing considers the dependency graph: each phase must compile independently before the next is started.

```
Phase 1: Native Foundation (macOS plumbing)
  → flutter create pro_orc --platforms=macos
  → Add tray_manager + window_manager to pubspec.yaml
  → Edit Info.plist: LSUIElement = true
  → Edit all entitlement files: app-sandbox = false
  → Implement platform/tray.dart + platform/window_manager.dart
  → Verify: app launches as menubar icon, main window shows on click

  WHY FIRST: Validates the native integration that blocks everything else.
  A sandbox misconfiguration discovered in Phase 4 means rewriting Phase 2-3 work.

Phase 2: Models (pure Dart, no Flutter)
  → models/project.dart (sealed class: CodeProject, ResearchProject)
  → models/gsd_state.dart (GsdPhase, NextStep, RoadmapProgress)
  → models/git_info.dart (GitInfo with parse() factory)
  → models/claude_tool.dart (ClaudeTool)

  WHY HERE: Models have no deps. Define data shapes before services that produce them.

Phase 3: Services (pure Dart, unit-testable)
  → services/project_scanner.dart
  → services/gsd_parser.dart
  → services/git_reader.dart
  → Add test/services/ with unit tests (no Flutter required)

  WHY BEFORE RIVERPOD: Services are testable without any Flutter infrastructure.
  Validating parsing logic in tests is far faster than running the full app.

Phase 4: Background Worker + Git Concurrency
  → isolates/git_worker.dart
  → Concurrency-capped Future.wait pattern in git_worker

  WHY HERE: Git is the first real performance concern. Proving the isolate pattern
  before wiring it into Riverpod avoids debugging two systems simultaneously.

Phase 5: Riverpod Providers
  → Add flutter_riverpod + riverpod_annotation + riverpod_generator to pubspec.yaml
  → providers/watcher_provider.dart (StreamProvider + keepAlive)
  → services/watcher_service.dart (DirectoryWatcher streams)
  → providers/projects_provider.dart (AsyncNotifier + ref.listen)
  → providers/tools_provider.dart (FutureProvider)

  WHY HERE: Providers are thin wrappers. Services must exist before providers can wrap them.

Phase 6: UI — Card Grid
  → ui/theme/app_theme.dart (dark, macOS-native)
  → ui/widgets/phase_badge.dart
  → ui/widgets/git_info_row.dart
  → ui/widgets/project_card.dart
  → ui/widgets/research_card.dart
  → ui/windows/main_window.dart (card grid layout)

  WHY HERE: Widget tree needs providers from Phase 5. Build top-down: atoms first (badge),
  then molecules (card), then layouts (window).

Phase 7: Live Updates (watcher → invalidation → UI)
  → Connect watcherProvider to projectsProvider via ref.listen
  → Test end-to-end: edit STATE.md → card updates without restart
  → Tune debounce (many rapid FS events on git commit = multiple invalidations)

Phase 8: Claude Tools Inventory
  → services/tools_scanner.dart
  → providers/tools_provider.dart (already scaffolded in Phase 5)
  → ui/widgets/tools_panel.dart
  → Integrate into main_window.dart layout

  WHY LAST: Independent feature. Does not block any other phase.
```

---

## Scaling Considerations

This is a personal single-user tool. Scale concerns are about local data volume, not concurrent users.

| Scale | Architecture Adjustment |
|-------|------------------------|
| <20 projects | Main isolate git calls fine; no background isolate needed |
| 20–50 projects | Background isolate with 4-concurrent cap (already in Phase 4 design) |
| >50 projects | Add disk cache: write `~/.pro-orc-cache.json` on scan; skip git on projects with unchanged mtime; load cache on startup while re-scan runs in background |

**First bottleneck:** Git subprocess calls. 50 projects × ~150ms per `git log` = 7.5 seconds if sequential. Fix: concurrency cap to 4 parallel isolates cuts to ~2 seconds. Already addressed in Phase 4 design.

**Second bottleneck:** Directory walk depth into `node_modules`. The scanner must ignore `node_modules`, `.git`, `.venv`, `.next`, `build/`, `dist/` at depth > 1. Same `ignored` pattern list as chokidar v1.0.

---

## Sources

- Flutter macOS building + sandbox entitlements: https://docs.flutter.dev/platform-integration/macos/building
  (HIGH confidence — official Flutter docs)
- tray_manager package: https://pub.dev/packages/tray_manager
  (MEDIUM confidence — WebSearch verified, leanflutter maintained)
- window_manager package: https://pub.dev/packages/window_manager
  (MEDIUM confidence — WebSearch verified, same author as tray_manager)
- Dart watcher package: https://pub.dev/packages/watcher
  (HIGH confidence — Dart team maintained, pub.dev official)
- Flutter isolates + background work: https://docs.flutter.dev/perf/isolates
  (HIGH confidence — official Flutter docs)
- Dart isolate language reference: https://dart.dev/language/isolates
  (HIGH confidence — official Dart docs)
- Riverpod 3.0 changes: https://riverpod.dev/docs/whats_new
  (MEDIUM confidence — WebSearch, not directly fetched)
- Riverpod AsyncNotifier pattern (codewithandrea): https://codewithandrea.com/articles/flutter-riverpod-async-notifier/
  (MEDIUM confidence — established Flutter community resource)
- Flutter macOS menubar implementation: https://blog.whidev.com/menu-bar-extra-flutter-macos-app/
  (MEDIUM confidence — WebSearch, practitioner blog)
- Flutter menubar example template: https://github.com/mynameiskenlee/flutter_macos_menubar_example
  (MEDIUM confidence — WebSearch, community starter)
- macOS sandbox + subprocess issues: https://github.com/flutter/flutter/issues/66920
  (MEDIUM confidence — WebSearch, GitHub issue thread)
- Flutter app architecture with Riverpod: https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/
  (MEDIUM confidence — WebSearch, established reference)
- Riverpod + repository pattern: https://codewithandrea.com/articles/flutter-repository-pattern/
  (MEDIUM confidence — WebSearch)

---
*Architecture research for: Pro Orc v1.1 — Flutter macOS desktop dashboard*
*Researched: 2026-02-19*
