# Phase 8: Reactive State — Research

**Researched:** 2026-02-19
**Domain:** Dart file watching, Riverpod state management, debounce, update animation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Watcher behavior:**
- Neue Projektverzeichnisse unter ~/project_orchestration/ werden live erkannt — neues Verzeichnis = neues Projekt erscheint automatisch
- Alle Event-Typen werden verarbeitet: modify, create, delete — nicht nur modify
- Watch-Scope und Start-Timing: Claude's Discretion (basierend auf Requirements und Ressourcen-Trade-offs)

**Debounce & Batching:**
- Debounce-Wert und Konfigurierbarkeit: Claude's Discretion
- Pro-Projekt vs. globaler Batch: Claude's Discretion
- Leading vs. trailing edge: Claude's Discretion
- Visuelles Update-Signal: Ja — subtile Animation oder Highlight wenn eine Card sich aktualisiert (kein stilles Update)

**Fehler & Edge Cases:**
- Ungültige/korrupte STATE.md: Fehlerstatus in der Card anzeigen (nicht alte Daten still behalten)
- Gelöschtes Projektverzeichnis: Card sofort aus der Ansicht entfernen
- Watcher-Fehler (Berechtigungen, unerreichbare Verzeichnisse): Dezentes UI-Signal, z.B. kleines Icon in der Statusleiste
- dart-lang/watcher#79 (isDirectory assertion crash): Explizit absichern mit defensivem Code, egal ob in aktueller Version gefixt oder nicht

**Specific Ideas:**
- Update-Animation soll subtil sein — kein Flackern, eher kurzes Highlight/Glow passend zum n3urala1 Theme
- `watcherProvider` uses `ref.keepAlive()` — never disposed; `projectsProvider` invalidates on watcher events

### Claude's Discretion

- Watch-Scope (nur .planning/ vs. breiter) — basierend auf Requirements LIVE-01, LIVE-02, LIVE-03
- Watcher Start-Timing (sofort vs. bei Fenster-Öffnung) — basierend auf Ressourcen-Trade-offs
- Debounce-Wert fest vs. konfigurierbar
- Pro-Projekt-Debounce vs. globaler Batch
- Leading/trailing edge Trigger-Strategie
- Provider-Architektur (keepAlive-Strategie, Invalidierungs-Granularität)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIVE-01 | File-Watching via `watcher` Package mit Debounce (350ms) | `DirectoryWatcher.events` is a broadcast stream; debounce implemented via `dart:async` Timer or `stream_transform` package |
| LIVE-02 | StreamController.broadcast() → StreamBuilder für reaktive Card-Updates | Riverpod `StreamProvider` wraps the watcher broadcast stream; widgets use `ref.watch` on the events stream or `ref.listen` to trigger invalidation |
| LIVE-03 | Cards aktualisieren sich automatisch bei Filesystem-Änderungen | `projectsProvider` (FutureProvider) is invalidated by watcher events via `ref.listen`, triggering a full rescan and UI rebuild |
</phase_requirements>

---

## Summary

Phase 8 wires together three layers: a `watcher`-backed file watcher service, a Riverpod provider graph that propagates change events, and UI update animations. The `watcher` package (now at 1.2.1) is the correct tool for the file-watching layer — it is the dart-lang official package, returns a broadcast `Stream<WatchEvent>`, and supports all three event types (modify, create, delete) out of the box. The macOS assertion crash (issue #79 / `assert(false)` on `modifyDirectory`) was fixed in watcher 1.2.1, but defensive code should still be written as instructed.

Riverpod is not yet in the project's `pubspec.yaml`. This phase adds it for the first time. The current version is `flutter_riverpod: ^3.2.1`. This requires wrapping `runApp` with `ProviderScope` in `main.dart`. The architecture is: `watcherProvider` (keepAlive StreamProvider) → emits `WatchEvent`s → `ref.listen` in `projectsProvider` calls `ref.invalidate(projectsProvider)` → triggers full rescan via `ProjectScanner.scanAll()` → widgets rebuild. Debounce belongs in the watcher service layer (before events enter Riverpod), implemented with a `Timer`-based trailing-edge debounce at 350ms.

For the update animation, `TweenAnimationBuilder` wrapping an `AnimatedContainer` color change is the standard Flutter approach without extra dependencies. Alternatively, `flutter_animate` (4.5.2) provides a `.shimmer()` or custom glow effect via the `.animate()` extension method and is more expressive for the n3urala1 theme. The animation must be triggered per-card when its underlying data changes — this is done by tracking a "last updated" timestamp or version counter in the project state.

**Primary recommendation:** Add `flutter_riverpod: ^3.2.1` and `watcher: ^1.2.1`. Use `stream_transform` (already in the dart-lang ecosystem) for `.debounce()` on the watcher stream. Use `TweenAnimationBuilder` for the update highlight — no new dependency required.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^3.2.1 | State management — providers, streaming, invalidation | Established Flutter state management for this project (decided in CONTEXT.md) |
| watcher | ^1.2.1 | File system watching — DirectoryWatcher with broadcast stream | dart-lang official package; 8M+ downloads; macOS assert crash fixed in 1.2.1 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| stream_transform | ^2.1.1 | `.debounce(Duration)` extension on Stream | Cleaner than manual Timer; dart-lang official (tools.dart.dev); already transitive in many projects |
| flutter_animate | ^4.5.2 | Card highlight animation (.shimmer, .tint) | If TweenAnimationBuilder proves too verbose for the glow effect; Flutter Favorite |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| stream_transform | rxdart debounceTime | rxdart is heavier (full ReactiveX port); stream_transform is dart-lang official and minimal |
| TweenAnimationBuilder | flutter_animate | flutter_animate is more expressive for complex effects but adds a dependency; TweenAnimationBuilder needs zero new packages |
| watcher | dart:io FileSystemEntity.watch() | dart:io watch() has known macOS reliability issues; watcher abstracts platform differences |

**Installation:**
```yaml
dependencies:
  flutter_riverpod: ^3.2.1
  watcher: ^1.2.1
  stream_transform: ^2.1.1   # optional — can use manual Timer instead
```

---

## Architecture Patterns

### Recommended Project Structure

```
pro_orc/lib/
├── data/
│   ├── services/
│   │   ├── project_scanner.dart     # existing — unchanged
│   │   └── watcher_service.dart     # NEW — wraps DirectoryWatcher, exposes debounced stream
│   └── ...
├── providers/
│   ├── watcher_provider.dart        # NEW — StreamProvider(keepAlive), wraps WatcherService
│   └── projects_provider.dart       # NEW — FutureProvider, calls ProjectScanner.scanAll()
├── features/
│   └── dashboard/
│       ├── project_card.dart        # NEW or updated — ConsumerWidget with update animation
│       └── dashboard_screen.dart    # NEW or updated — ConsumerWidget watching projectsProvider
└── main.dart                        # UPDATED — wrap with ProviderScope
```

### Pattern 1: ProviderScope at Root

**What:** All Riverpod providers require `ProviderScope` to wrap the widget tree.
**When to use:** Phase 8 entry point — wrap `runApp` in `main.dart`.
**Example:**
```dart
// Source: https://riverpod.dev/docs/introduction/getting_started
void main() {
  runApp(
    ProviderScope(
      child: ProOrcApp(),
    ),
  );
}
```

### Pattern 2: WatcherService — DirectoryWatcher with Debounce

**What:** A plain Dart service class that creates a `DirectoryWatcher` and returns a debounced broadcast stream of `WatchEvent`s.
**When to use:** Isolates watcher logic from Riverpod — keeps it testable.
**Example:**
```dart
// Source: pub.dev/packages/watcher, pub.dev/packages/stream_transform
import 'package:watcher/watcher.dart';
import 'package:stream_transform/stream_transform.dart';

class WatcherService {
  final String _rootDir;
  DirectoryWatcher? _watcher;

  WatcherService(this._rootDir);

  Stream<WatchEvent> get events {
    _watcher ??= DirectoryWatcher(_rootDir);
    return _watcher!.events
        .debounce(const Duration(milliseconds: 350));
  }

  Future<void> dispose() async {
    // DirectoryWatcher does not have an explicit dispose;
    // cancel stream subscriptions instead
  }
}
```

**Note on watch scope:** Watch the root scan directory (e.g., `~/project_orchestration/`) rather than individual `.planning/` subdirectories. This covers LIVE-01 (STATE.md changes), LIVE-02 (new project directories), and LIVE-03 automatically. Watching the root means fewer watcher instances and automatic detection of new/deleted project dirs.

### Pattern 3: watcherProvider — StreamProvider with keepAlive

**What:** A Riverpod `StreamProvider` that wraps `WatcherService.events`. Uses `ref.keepAlive()` so it is never disposed, per the locked decision.
**When to use:** Single source of truth for file change events.
**Example:**
```dart
// Source: https://github.com/rrousselgit/riverpod (Context7)
// Non-codegen manual syntax — no build_runner step required
final watcherProvider = StreamProvider<WatchEvent>((ref) {
  ref.keepAlive(); // never disposed — locked decision from CONTEXT.md

  final service = WatcherService(
    ref.read(appConfigProvider).scanDir,
  );

  ref.onDispose(() {
    // cleanup if ever needed despite keepAlive
  });

  return service.events;
});
```

**Why non-codegen:** The project's existing Phase 7 providers (AppDatabase, ProjectScanner) are injected manually without Riverpod code generation. Consistent approach — no `riverpod_generator` or `riverpod_annotation` needed. No additional `build_runner` step.

### Pattern 4: projectsProvider — FutureProvider invalidated by watcher

**What:** A Riverpod `FutureProvider` that calls `ProjectScanner.scanAll()`. Uses `ref.listen` on `watcherProvider` to call `ref.invalidate(projectsProvider)` on every watcher event.
**When to use:** This is the chain linkage — watcher event → invalidate → rescan → UI rebuild.
**Example:**
```dart
// Source: https://github.com/rrousselgit/riverpod (Context7)
final projectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  // Listen to watcher events and invalidate self on any change.
  // ref.listen fires on every new stream value.
  ref.listen(watcherProvider, (previous, next) {
    ref.invalidate(projectsProvider);
  });

  final db = ref.read(appDatabaseProvider);
  final scanner = ProjectScanner(db);
  return scanner.scanAll();
});
```

**Invalidation granularity:** A global invalidate (entire project list rescanned) is appropriate for Phase 8. Per-project invalidation is possible later but requires tracking which project path changed and mapping to provider families — deferred to future phases.

### Pattern 5: ConsumerWidget — watching projectsProvider

**What:** Dashboard widget that rebuilds when `projectsProvider` completes.
**Example:**
```dart
// Source: https://github.com/rrousselgit/riverpod (Context7)
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return switch (projectsAsync) {
      AsyncData(:final value) => ProjectGrid(projects: value),
      AsyncError(:final error) => ErrorView(error: error),
      _ => const LoadingIndicator(),
    };
  }
}
```

### Pattern 6: Per-Card Update Animation

**What:** A card widget that plays a brief highlight when its underlying `ProjectModel` changes. Implemented with `TweenAnimationBuilder` + a version key or timestamp trigger.
**When to use:** The locked decision requires a visual update signal — not a silent update.
**Example:**
```dart
// Source: https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html
// Pattern: store a "version" int that increments when data changes;
// use Key(version) on the TweenAnimationBuilder to restart animation on rebuild.

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final int version; // increments on each data update

  const ProjectCard({required this.project, required this.version, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      key: ValueKey(version),
      tween: ColorTween(
        begin: const Color(0xFF3A1F5C), // accent-purple highlight
        end: Colors.transparent,
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, color, child) {
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
      child: CardContent(project: project),
    );
  }
}
```

**Alternative with flutter_animate:**
```dart
// Cleaner syntax but adds dependency
CardContent(project: project)
  .animate(key: ValueKey(version))
  .tint(color: const Color(0xFF3A1F5C), duration: 600.ms, curve: Curves.easeOut)
  .tint(color: Colors.transparent, delay: 100.ms, duration: 500.ms)
```

### Anti-Patterns to Avoid

- **Watching individual project subdirectory per project:** Creates N watcher instances (one per project). Watch the root instead and filter events in the service layer.
- **Calling `ref.invalidate` inside a `build` method:** Use `ref.listen` in a provider body or `ref.listen` in a widget — never trigger invalidation during build.
- **Using `StreamProvider.autoDispose` for watcherProvider:** The locked decision is `keepAlive`. `autoDispose` would destroy the watcher when no widget is listening (e.g., window minimized), meaning changes during that period are missed.
- **Debouncing inside the provider instead of the service:** Debounce belongs in `WatcherService` before events enter Riverpod. Debouncing inside the provider is possible but harder to test.
- **Using `dart:io FileSystemEntity.watch()`:** Lower-level, more fragile on macOS, no built-in debounce, no `WatchEvent` abstraction. Always use the `watcher` package.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File system watching | Custom FSEvent/inotify wrapper | `watcher` package | Platform differences (macOS FSEvents, Linux inotify, Windows ReadDirectoryChangesW), symlink edge cases, retry logic on close |
| Stream debouncing | Timer-per-event manual tracking | `stream_transform` `.debounce()` or manual trailing-edge Timer | Multiple simultaneous events, timer cancellation, race conditions |
| Provider state management | setState + callbacks | Riverpod FutureProvider + invalidate | Automatic loading/error states, widget rebuild scoping, testability |

**Key insight:** File watching on macOS has historically been fragile. The `watcher` package handles FSEvents edge cases (duplicate events, directory rename overlaps, assert crashes) that took years of bug reports to get right. Never bypass it.

---

## Common Pitfalls

### Pitfall 1: watcher#79 — isDirectory Assertion Crash on macOS

**What goes wrong:** In debug builds on macOS, a `modifyDirectory` FSEvent arrives with `isDirectory: true`. Older watcher versions had an `assert(!event.isDirectory)` that crashes the app in debug mode.
**Why it happens:** macOS FSEvents sometimes emits directory-level modify events when files inside are changed. The watcher implementation incorrectly asserted that only file events would arrive.
**How to avoid:**
1. Use `watcher: ^1.2.1` — the assert was removed in this version ("on Mac, stop issuing `assert(false)` when a `modifyDirectory` event is ignored").
2. Per locked decision: still add defensive try/catch around watcher event processing regardless of version.
**Warning signs:** App crashes in debug mode on macOS when editing files; "Failed assertion: '!event.isDirectory': is not true" in stack trace.

**Confidence:** HIGH — verified via pub.dev/packages/watcher/changelog

### Pitfall 2: Riverpod Version Mismatch (v2 vs v3 API)

**What goes wrong:** Riverpod 3.0 (released ~September 2025) changed the `Ref` API — no more `Ref<T>`, no `FutureProviderRef`, `StreamProviderRef` — just a unified `Ref`. Code examples from pre-3.0 articles use the old generic refs.
**Why it happens:** Majority of tutorials and StackOverflow answers are for Riverpod 2.x.
**How to avoid:** Use the `flutter_riverpod: ^3.2.1` API. All provider callbacks take `Ref ref` (no type parameter). Check official docs at riverpod.dev, not Medium articles.
**Warning signs:** Compile errors on `Ref<List<ProjectModel>>` or `FutureProviderRef` type annotations.

**Confidence:** HIGH — verified via riverpod.dev/docs/whats_new and Context7

### Pitfall 3: Missing ProviderScope Causes Runtime Error

**What goes wrong:** All Riverpod `ref.watch`/`ref.read` calls fail at runtime with "ProviderScope not found in widget tree."
**Why it happens:** `ProviderScope` must be the root of the widget tree. The current `main.dart` uses plain `runApp(const ProOrcApp())` — no ProviderScope.
**How to avoid:** Wrap `runApp` with `ProviderScope` in `main.dart` as the very first step of Phase 8.
**Warning signs:** FlutterError at app startup about missing ProviderScope.

**Confidence:** HIGH — verified via riverpod.dev

### Pitfall 4: Debounce Too Short Causes Repeated Rescans on Auto-Save

**What goes wrong:** Editor auto-save writes multiple files rapidly (e.g., saves STATE.md then ROADMAP.md within 50ms). Without sufficient debounce, each write triggers a separate `ProjectScanner.scanAll()` call — success criteria LIVE-01 explicitly requires exactly one refresh for rapid saves.
**Why it happens:** File system watchers emit one event per file write, not one event per "save session."
**How to avoid:** 350ms trailing-edge debounce (per LIVE-01). This is enough to absorb typical auto-save bursts (VSCode default 1000ms delay, most editors 300–500ms between files).
**Warning signs:** Multiple rapid UI flickers when saving one file; `scanAll()` called more than once per user save action.

**Confidence:** HIGH — requirement is explicit in LIVE-01

### Pitfall 5: WatchEvent for Deleted Project Directory

**What goes wrong:** When a project directory is deleted, `watcher` emits `ChangeType.REMOVE` events for all files inside, then the directory itself. If `ProjectScanner.scanAll()` is called before all events are processed, the scan still sees the directory briefly (race condition), or throws because the directory is gone mid-scan.
**Why it happens:** File system events and actual OS directory removal are not atomic.
**How to avoid:** `ProjectScanner.scanAll()` already handles non-existent directories gracefully (returns null git/gsd fields). The locked decision says to remove the card immediately — the rescan after the debounce window will naturally produce a list without the deleted project.
**Warning signs:** Deleted project card briefly persists after deletion, or `ScanDirectoryNotFoundError` thrown during transition.

**Confidence:** MEDIUM — inferred from watcher behavior, not directly tested

### Pitfall 6: StreamProvider Pauses When Not Listened (Riverpod 3.0 Behavior)

**What goes wrong:** In Riverpod 3.0, StreamProvider pauses its StreamSubscription when no widgets are listening. For `watcherProvider`, this means the file watcher stream would be paused when the window is hidden/closed.
**Why it happens:** New Riverpod 3.0 behavior — Stream subscriptions are paused by default when providers are not actively listened.
**How to avoid:** `ref.keepAlive()` prevents the provider from being disposed, but stream pausing is a different mechanism. Ensure the watcher's `DirectoryWatcher` subscription is kept alive with an explicit `StreamSubscription` that is never paused. In practice: subscribe in the `WatcherService`, not via Riverpod's `StreamProvider` stream forwarding, or use a `Provider` that holds the `WatcherService` and manages its own subscriptions.
**Warning signs:** File changes during window-hidden period are missed; provider catches up only when window is focused again.

**Confidence:** MEDIUM — based on Riverpod 3.0 docs, stream pause behavior needs validation

---

## Code Examples

Verified patterns from official sources:

### DirectoryWatcher Basic Usage
```dart
// Source: pub.dev/packages/watcher API docs
import 'package:watcher/watcher.dart';

final watcher = DirectoryWatcher('/path/to/watch');

// watcher.events is a broadcast Stream<WatchEvent>
final subscription = watcher.events.listen((WatchEvent event) {
  print('${event.type}: ${event.path}');
  // event.type: ChangeType.ADD, ChangeType.MODIFY, ChangeType.REMOVE
  // event.path: absolute path to changed file
});

// Wait for watcher to be ready
await watcher.ready;
```

### stream_transform Debounce
```dart
// Source: pub.dev/packages/stream_transform
import 'package:stream_transform/stream_transform.dart';

final debouncedStream = watcher.events.debounce(
  const Duration(milliseconds: 350),
);
// Trailing-edge: emits the LAST event after 350ms of silence
```

### Manual Timer Debounce (no extra package)
```dart
// Source: dart:async Timer
Timer? _debounce;

void _onEvent(WatchEvent event) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 350), () {
    // process event
  });
}
```

### Riverpod StreamProvider (non-codegen, Riverpod 3.0)
```dart
// Source: Context7 /rrousselgit/riverpod
// Unified Ref (no type parameter) — Riverpod 3.0 syntax
final watcherProvider = StreamProvider<WatchEvent>((ref) {
  ref.keepAlive(); // never disposed

  final service = WatcherService(scanDir);
  ref.onDispose(service.dispose);

  return service.events;
});
```

### Riverpod FutureProvider with ref.listen for invalidation
```dart
// Source: Context7 /rrousselgit/riverpod
final projectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  // React to watcher events by invalidating self
  ref.listen(watcherProvider, (previous, next) {
    ref.invalidate(projectsProvider);
  });

  final scanner = ref.read(projectScannerProvider);
  return scanner.scanAll();
});
```

### ConsumerWidget pattern (Riverpod 3.0)
```dart
// Source: Context7 /rrousselgit/riverpod
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return switch (projects) {
      AsyncData(:final value) => ProjectGrid(projects: value),
      AsyncError(:final error) => ErrorView(error: error),
      _ => const CircularProgressIndicator(),
    };
  }
}
```

### TweenAnimationBuilder Update Flash
```dart
// Source: https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html
// Restart animation by changing the Key when data updates
TweenAnimationBuilder<Color?>(
  key: ValueKey(project.lastUpdatedVersion), // changes on update
  tween: ColorTween(
    begin: const Color(0x443A1F5C), // subtle purple tint
    end: Colors.transparent,
  ),
  duration: const Duration(milliseconds: 800),
  curve: Curves.easeOut,
  builder: (context, color, child) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child!,
  ),
  child: CardContent(project: project),
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `dart:io FileSystemEntity.watch()` directly | `watcher` package | Long-standing | Handles macOS FSEvents edge cases, reconnect on close, platform abstraction |
| Riverpod `Ref<T>` typed refs (`FutureProviderRef`, etc.) | Unified `Ref` (no type param) | Riverpod 3.0 (Sept 2025) | Simpler API; old typed ref code doesn't compile |
| `StreamProvider` never pauses | StreamProvider pauses subscription when no listeners | Riverpod 3.0 | Use `ref.keepAlive()` + manage subscription carefully for always-on watchers |
| `dart-archive/watcher` (old repo) | `dart-lang/tools/pkgs/watcher` | Migrated ~2023 | Repository moved; pubspec ref remains `watcher` |

**Deprecated/outdated:**
- `DirectoryWatcher.directory` property: deprecated, use `DirectoryWatcher.path` instead.
- `dart-archive/watcher` GitHub repo: archived, superseded by `dart-lang/tools`.
- Riverpod `ProviderReference` / `ScopedReader`: removed in Riverpod 2.0+; not applicable.

---

## Recommendations for Claude's Discretion Areas

### Watch-Scope
**Recommendation: Watch the root scan directory (`~/project_orchestration/`), not individual `.planning/` subdirectories.**

Reasoning: A single `DirectoryWatcher` on the root covers all three requirements — LIVE-01 (STATE.md changes), LIVE-02 (new project dirs), LIVE-03 (card auto-update). Watching individual `.planning/` subdirs would require N watchers (one per project), miss new project creation (the directory doesn't exist yet to watch), and add complexity. The root watcher emits events for all nested files; filtering by path suffix (`.planning/STATE.md`, `.planning/ROADMAP.md`) in the service is trivial.

### Watcher Start-Timing
**Recommendation: Start watcher on `ProviderScope` initialization (i.e., immediately on app start), not on window open.**

Reasoning: The watcher is `keepAlive` (never disposed). Delaying to window-open introduces a window where file changes are missed. The resource cost of one `DirectoryWatcher` instance on macOS (using FSEvents) is negligible — it's a kernel-level callback, not polling.

### Debounce Strategy
**Recommendation: 350ms trailing-edge debounce, fixed value, applied globally (not per-project).**

Reasoning: 350ms is specified in LIVE-01. Trailing-edge means the rescan fires after the last event in a burst — correct behavior for save bursts. Global debounce (one timer for all events) is simpler and correct: we always do a full `scanAll()` regardless of which project changed, so batching all events into one trigger is optimal.

### Provider Architecture (keepAlive + Invalidation)
**Recommendation: Use non-codegen manual `StreamProvider` and `FutureProvider`. Add `Provider` wrapper for `ProjectScanner` and `AppDatabase` instances.**

Reasoning: The project already uses manual dependency injection (no Riverpod codegen). Mixing codegen and non-codegen adds `build_runner` complexity. The locked keepAlive on `watcherProvider` is a single `ref.keepAlive()` call — trivial without codegen. The `ref.listen` + `ref.invalidate` pattern for watcher → projects chain is well-documented and straightforward.

---

## Open Questions

1. **Riverpod 3.0 StreamProvider stream pausing behavior**
   - What we know: Riverpod 3.0 pauses StreamSubscriptions when no listeners; `ref.keepAlive()` prevents disposal but may not prevent pause.
   - What's unclear: Whether `ref.keepAlive()` alone prevents stream pausing, or whether an explicit never-cancelled subscription is needed.
   - Recommendation: During implementation, verify by running the app with window hidden, editing a file, then focusing the window — if the card updates, stream was not paused. If not, switch from `StreamProvider` to `Provider<WatcherService>` with a manually managed subscription.

2. **`DirectoryWatcher` recursive vs. non-recursive behavior**
   - What we know: `DirectoryWatcher` watches a directory and its contents.
   - What's unclear: Whether it watches recursively (subdirectories) by default on macOS, or only the top-level.
   - Recommendation: The `watcher` package documentation states it monitors "changes to contents of directories." In practice on macOS (FSEvents), it watches recursively. Validate in an early implementation task by editing a nested file (e.g., `project_a/.planning/STATE.md`) and confirming an event is emitted.

3. **Animation trigger mechanism**
   - What we know: `TweenAnimationBuilder` restarts when its `Key` changes; `ValueKey(version)` where `version` is an int works.
   - What's unclear: Whether `ProjectModel` should carry a `version` field, or whether the animation tracks changes by comparing old/new model values.
   - Recommendation: Add a `lastUpdatedAt` (DateTime) field to `ProjectModel` or a simple `version` int. The card widget uses `ValueKey(project.lastUpdatedAt)` to restart the animation on data change.

---

## Sources

### Primary (HIGH confidence)
- Context7 `/rrousselgit/riverpod` — StreamProvider, keepAlive, ref.listen, ref.invalidate, ref.watch, ConsumerWidget patterns
- `https://pub.dev/packages/watcher/changelog` — Version history, 1.2.1 macOS assert fix confirmed
- `https://pub.dev/packages/flutter_riverpod` — Latest version 3.2.1, installation, ProviderScope
- `https://pub.dev/documentation/watcher/latest/watcher/DirectoryWatcher-class.html` — API: events stream, isReady, ready, path, constructor

### Secondary (MEDIUM confidence)
- `https://riverpod.dev/docs/whats_new` — Riverpod 3.0 breaking changes: unified Ref, StreamProvider pause behavior
- `https://pub.dev/packages/stream_transform` — debounce API, dart-lang official, version 2.1.1
- `https://pub.dev/packages/flutter_animate` — Version 4.5.2, animate extension, onPlay controller pattern
- `https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html` — TweenAnimationBuilder Key-restart pattern

### Tertiary (LOW confidence)
- GitHub issue dart-lang/watcher#79 — Marked "seems to be fixed" Dec 2020 by reporter; watcher 1.2.1 changelog confirms macOS assert removal (links the two)
- Medium/blog search results on debounce patterns — Not directly used; standard Timer debounce confirmed via dart:async docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — watcher 1.2.1 and flutter_riverpod 3.2.1 verified on pub.dev; stream_transform verified as dart-lang official
- Architecture: HIGH — provider patterns verified in Context7 official Riverpod docs; watcher API verified in pub.dev docs
- Pitfalls: HIGH for watcher bug + Riverpod setup; MEDIUM for stream pause behavior (requires runtime validation)

**Research date:** 2026-02-19
**Valid until:** 2026-03-19 (30 days — both watcher and Riverpod are stable packages)
