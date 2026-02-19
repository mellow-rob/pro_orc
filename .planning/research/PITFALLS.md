# Domain Pitfalls

**Domain:** Flutter macOS Desktop App — Project Orchestration Dashboard (Pro Orc rewrite from Next.js)
**Researched:** 2026-02-19
**Confidence:** MEDIUM-HIGH. Critical pitfalls verified against Flutter GitHub issues and official docs. Some specifics (OKLCH conversions, exact API behavior under Impeller) are MEDIUM — confirmed directionally from multiple sources but not exhaustively tested.

---

## Critical Pitfalls

Mistakes that cause rewrites, crashes, or complete feature failure.

---

### Pitfall 1: macOS Sandbox Blocks All Filesystem Access — Silent at Build Time

**What goes wrong:** Flutter macOS apps run inside Apple's App Sandbox by default. Any `File.readAsBytes()`, `Directory.list()`, or `FileSystemEntity.watch()` call against paths outside the app's own container (e.g., `~/project_orchestration/`) fails at runtime with `FileSystemException: Cannot open file, OS Error: Operation not permitted, errno = 1`. This is not a compile-time error. Debug builds via `flutter run` may work differently than release builds because the sandbox enforcement differs between configurations.

**Why it happens:** Flutter generates two entitlement files: `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`. The debug file includes JIT exceptions needed for development. Developers test with `flutter run`, assume it works, then discover the release build is completely broken because `Release.entitlements` was never updated. For a single-user, direct-distribution (not App Store) app, the sandbox is still active but you have more latitude — you can disable it entirely or add broad entitlements. The official Flutter docs only document user-file-picker access, not programmatic broad access.

**How to avoid:** For a direct-distribution (non-App Store) app, disable the sandbox entirely by removing `com.apple.security.app-sandbox` from **both** entitlement files:
```xml
<!-- macos/Runner/DebugProfile.entitlements AND Release.entitlements -->
<!-- Remove or set to false: -->
<!-- <key>com.apple.security.app-sandbox</key><true/> -->
```
Or, if you want to keep the sandbox for any reason, add:
```xml
<key>com.apple.security.files.user-selected.read-write</key><true/>
```
But note: `user-selected` only covers paths the user explicitly opened via a file picker — it does NOT cover programmatic access to `~/project_orchestration/`. For Pro Orc's use case (watching a known directory), disabling the sandbox is the right call.

**Warning signs:**
- `flutter run` works but `flutter build macos && open build/macos/Build/Products/Release/ProOrc.app` fails
- Any `FileSystemException` with `errno = 1` or `errno = 13`
- App works for the first launch then fails on restart (sandbox container paths differ)

**Phase to address:** Phase 1 (Foundation/Setup). Set this before writing a single line of filesystem code. Verify by running the built `.app`, not `flutter run`.

---

### Pitfall 2: Dart `Process.run()` Cannot Find `git` — PATH Not Inherited from Shell

**What goes wrong:** When Flutter macOS apps spawn subprocesses via `Process.run('git', [...])`, they inherit the environment from the macOS Launch Services environment, NOT the user's shell environment. On macOS, the Launch Services PATH is `/usr/bin:/bin:/usr/sbin:/sbin`. If the user installed git via Homebrew (`/opt/homebrew/bin/git` on Apple Silicon, `/usr/local/bin/git` on Intel), `Process.run('git', [...])` throws `ProcessException: No such file or directory` — even though `git` works fine in the terminal.

This is a confirmed Dart SDK issue (dart-lang/sdk#38364) and differs from Node.js behavior, where `child_process.exec()` uses the shell and inherits PATH normally.

**Why it happens:** macOS GUI apps launched via `.app` bundles receive a minimal environment from LaunchServices. `flutter run` also spawns the app as a subprocess of the terminal, so it inherits the terminal's PATH — masking the problem during development. The built `.app` does not have this inheritance.

**How to avoid:**
```dart
// Option 1: Use the full path (reliable but fragile if Homebrew prefix differs)
final result = await Process.run('/opt/homebrew/bin/git', ['status', '--porcelain'],
  workingDirectory: projectPath,
);

// Option 2: Resolve git path at startup using `which`
Future<String> resolveGitPath() async {
  // Try common locations
  final candidates = [
    '/opt/homebrew/bin/git',  // Apple Silicon Homebrew
    '/usr/local/bin/git',     // Intel Homebrew
    '/usr/bin/git',           // System git (Xcode CLT)
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  throw Exception('git not found. Install Xcode Command Line Tools.');
}

// Option 3: runInShell: true (uses /bin/sh which sources /etc/paths)
final result = await Process.run('git', ['status'],
  workingDirectory: projectPath,
  runInShell: true,  // /bin/sh inherits /etc/paths — usually enough
);
```
`runInShell: true` is the simplest approach and covers most cases. Cache the resolved git path at app startup, show an error UI if git is not found rather than silently failing.

**Warning signs:**
- `ProcessException: No such file or directory` when running git commands
- Works with `flutter run` but fails in the built `.app`
- Fails on a clean system with only Homebrew git installed

**Phase to address:** Phase 2 (Git Integration). Resolve git path in app initialization code, before any git calls.

---

### Pitfall 3: `Process.run()` / `Process.start()` Hangs on macOS Debug Builds (M1)

**What goes wrong:** On Apple Silicon Macs in debug mode, `Process.run()` and `Process.start()` can hang indefinitely after a few iterations. This is a confirmed Flutter issue (#95805). The process is spawned but never completes — `await Process.run()` never resolves, freezing the caller. The issue is intermittent and disappears in release builds or on Intel Macs, making it difficult to diagnose.

**Why it happens:** Suspected interaction between Dart's async runtime and the macOS process management on ARM under the JIT debugger. The issue is not fully resolved as of early 2026.

**How to avoid:**
- Always use `Process.run()` with a timeout wrapper during development:
```dart
Future<ProcessResult> runGitWithTimeout(String gitPath, List<String> args, {
  required String workingDirectory,
  Duration timeout = const Duration(seconds: 10),
}) async {
  return Process.run(gitPath, args, workingDirectory: workingDirectory)
    .timeout(timeout, onTimeout: () {
      throw TimeoutException('git $args timed out after ${timeout.inSeconds}s');
    });
}
```
- Test git integrations in **release mode** (`flutter run --release`) periodically — debug mode hangs may not appear in release.
- Keep subprocess calls minimal — avoid calling git on every file change event. Debounce to reduce invocation frequency.

**Warning signs:**
- App freezes on a screen that triggers git status
- `await Process.run()` never returns in debug mode
- CPU spikes with no observable output

**Phase to address:** Phase 2 (Git Integration). Add timeout wrappers around all process invocations. Test in release mode before marking phase complete.

---

### Pitfall 4: Dart File Watcher Misses Events and Coalesces Changes — Different from chokidar

**What goes wrong:** Dart's `FileSystemEntity.watch()` and the `watcher` package (the Dart team's high-level alternative) have macOS-specific behaviors that differ significantly from Node.js chokidar:

1. **Directory create events are sometimes omitted** (dart-lang/sdk#62124 — open issue as of 2026)
2. **Multiple changes in a short window are coalesced into a single event** — you may get one event for 50 file changes
3. **Events for files just before `watch()` started may arrive** — initial stale events can misfire
4. **`isDirectory` assertion failures** — the `watcher` package has a known `Failed assertion: '!event.isDirectory': is not true` crash on macOS when directory events arrive (dart-lang/watcher#79)

chokidar provides debounced, per-file events with `awaitWriteFinish`. Dart's watcher is lower-level and more raw.

**How to avoid:**
- Use the `watcher` package (pub.dev) instead of raw `FileSystemEntity.watch()` — it adds a normalization layer
- But wrap the `watcher` package with your own debounce (300ms minimum) because event coalescing can cause missed updates
- Do NOT rely on directory create events — use a polling fallback for directory-level changes if needed
- Wrap watcher initialization in try/catch — filesystem access may throw if sandbox is still active (see Pitfall 1)
```dart
// Debounce wrapper around watcher events
Timer? _debounce;
void _onFileChanged(WatchEvent event) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 350), () {
    _processChange(event);
  });
}
```

**Warning signs:**
- Dashboard misses updates when many files change simultaneously (e.g., `git checkout`)
- App crashes with `Failed assertion: '!event.isDirectory': is not true`
- Spurious events fire on app startup

**Phase to address:** Phase 2 (Filesystem Watching). Implement debouncing from day one.

---

### Pitfall 5: Menubar-Only App Requires Swift AppDelegate Changes — Not Dart-Only

**What goes wrong:** A "menubar only" app (no Dock icon, no window — just a status bar item with a popover) cannot be built in pure Dart/Flutter. It requires modifying `macos/Runner/AppDelegate.swift` to:
1. Set `NSApp.setActivationPolicy(.accessory)` to hide the Dock icon
2. Create `NSStatusItem` in AppKit
3. Manage a `NSPopover` containing the Flutter view

The `tray_manager` and `system_tray` packages provide a cross-platform tray icon with a context menu, but they do NOT provide:
- A popover/window attached to the tray icon (they show a context menu, not a Flutter UI)
- `LSUIElement` behavior (no Dock icon) — this requires `Info.plist` modification

Developers who expect `tray_manager` to do everything are surprised when the Flutter view is still showing in a separate main window with a Dock icon.

**How to avoid:**
1. Add `LSUIElement` to `macos/Runner/Info.plist`:
```xml
<key>LSUIElement</key>
<true/>
```
2. Modify `AppDelegate.swift` to suppress the default window and create the `NSStatusItem`. Use the community template at https://github.com/mynameiskenlee/flutter_macos_menubar_example as a reference.
3. Use `tray_manager` for the tray icon management in Dart, but the popover/window behavior requires native Swift code.

**Warning signs:**
- Dock icon is still visible after adding tray icon
- Tray icon click shows a right-click context menu instead of a popover window
- Main app window flashes on startup before being hidden

**Phase to address:** Phase 1 (Foundation/Setup). The AppDelegate architecture must be established before building any Dart UI.

---

### Pitfall 6: `BackdropFilter` Glassmorphism Has Multiple Impeller Rendering Bugs

**What goes wrong:** The project requires glassmorphism/blur effects. Flutter's `BackdropFilter(filter: ImageFilter.blur(...))` has documented Impeller rendering issues on macOS:

1. **Performance regression vs. Skia** — Impeller processes the entire screen to implement backdrop blur even when only a small region needs blurring. With multiple blur panels, this creates significant GPU load. Confirmed in flutter/flutter#149368.
2. **Artifacts at high sigma values** — Sigma values ≥ 40 produce visible rendering artifacts when content scrolls under the blur. Confirmed in flutter/flutter#143947.
3. **White halo on dark backgrounds** — `BackdropFilter` samples pixels outside its clipped bounds, producing a white glow around blur containers on dark backgrounds. Confirmed in flutter/flutter#173530 — this is directly relevant to a dark-themed glassmorphism dashboard.
4. **Frame drops after sustained scrolling** — With multiple `BackdropFilter` widgets in a `ListView`, raster thread average degrades from ~6ms (Skia) to ~16ms (Impeller) with spikes to 24ms+ (flutter/flutter#126353).

**How to avoid:**
- Wrap every `BackdropFilter` in `RepaintBoundary` — this limits the repaint scope and prevents the entire widget tree from being repainted on every frame:
```dart
RepaintBoundary(
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
        ),
        child: content,
      ),
    ),
  ),
)
```
- Keep blur sigma between 5–15. Values above 20 look bad AND cause performance issues.
- Avoid `BackdropFilter` inside scrollable lists. Use a static background blur instead.
- For the white halo issue on dark backgrounds: add an explicit `ClipRRect` or `ClipPath` tightly around the `BackdropFilter`. The bug occurs when the blur samples outside the clip — explicit clipping constrains sampling.
- As a fallback, simulate glassmorphism with a semi-transparent `Container` + `Border` instead of actual blur — looks 90% as good without the GPU cost.

**Warning signs:**
- White glow/halo visible around glass cards on dark background
- Noticeable frame drops when scrolling past blur panels
- Strange smearing artifacts around blurred regions

**Phase to address:** Phase 3 (UI/Theming). Establish the glassmorphism pattern once and reuse it — don't let blur be added ad-hoc across components.

---

### Pitfall 7: OKLCH Colors Cannot Be Used Directly in Flutter's `Color` System

**What goes wrong:** The existing web dashboard uses OKLCH color values (e.g., `oklch(0.72 0.19 250)`) via CSS. Flutter's `Color` class uses ARGB integers. There is no native OKLCH support in Flutter's color system. Copying OKLCH values from CSS to Flutter silently produces wrong colors — the values are just interpreted as RGB components, resulting in completely different hues and luminance.

Additionally, Flutter's wide gamut color support (Display P3) is partial as of early 2026 — it applies to images, not to `Color` instances used in widgets. Using Display P3 OKLCH colors from the CSS design system in Flutter means colors will be clamped to sRGB.

**How to avoid:**
- At design time, convert all OKLCH values to sRGB hex using a tool like https://oklch.com or a design token pipeline. Accept that the colors will be sRGB approximations.
- If the exact color fidelity matters, use the `okcolor` or `canary_oklch` pub.dev packages which provide OKLCH-to-sRGB conversion at runtime:
```dart
// Using okcolor package
import 'package:okcolor/okcolor.dart';
final color = OKLCHColor(l: 0.72, c: 0.19, h: 250).toColor();
```
- For the Pro Orc dark theme, define colors as a `ThemeData` extension with pre-converted sRGB hex values. Do not try to port the CSS OKLCH values directly.

**Warning signs:**
- Colors in Flutter app look noticeably different from the web version
- Colors appear as unexpected hues (OKLCH values misinterpreted as RGB)
- Colors are slightly desaturated (P3 gamut compressed to sRGB)

**Phase to address:** Phase 3 (UI/Theming). Create a Dart color constants file with pre-converted OKLCH→sRGB hex values before building any UI components.

---

## Moderate Pitfalls

---

### Pitfall 8: Platform Channel Native Code Changes Require Full Restart — Not Hot Reload

**What goes wrong:** Flutter's hot reload does not apply to changes in Swift/Objective-C platform channel code (`macos/Runner/AppDelegate.swift`, any plugin native code). Developers making changes to Swift files expect hot reload to pick them up — it does not. More dangerous: hot reload may succeed without error but use the old native code, making it appear that the Swift change had no effect. This wastes significant debugging time.

**How to avoid:**
- Establish the rule from day one: **any change to `macos/Runner/*.swift` requires `flutter run` restart, not hot reload**
- Comment the Swift files prominently: `// Changes to this file require full restart (not hot reload)`
- Keep Swift code minimal — push logic to Dart wherever possible. The Swift side should only do what is impossible in Dart.

**Warning signs:**
- Swift changes appear to have no effect after hot reload
- Tray icon behavior changes not reflected after "r" in the terminal

**Phase to address:** Phase 1 (Foundation/Setup). Establish the development workflow expectation upfront.

---

### Pitfall 9: `tray_manager` Crashes on Menu Click When `app_links` Package Is Present

**What goes wrong:** If the app uses the `app_links` package (for URL scheme handling) alongside `tray_manager`, an older version of `app_links` internally blocks event propagation. This prevents tray menu click events from reaching the Dart handler — clicking a menu item does nothing, or the app crashes with an obscure `NSInvocation` error.

**How to avoid:**
- If using `app_links`, ensure version >= 6.3.3.
- Pro Orc does not need URL scheme handling (single-user local app), so do not add `app_links`. If needed later, pin to >= 6.3.3.
- Verify: after setting up `tray_manager`, click every menu item and confirm the Dart callback fires.

**Warning signs:**
- Tray menu items are visible but do nothing when clicked
- Console shows `NSInvocation` or event propagation errors

**Phase to address:** Phase 1 (Foundation/Setup, tray integration).

---

### Pitfall 10: `window_manager` App Window Appears Behind Other Windows on First Show

**What goes wrong:** After using `window_manager` to control the Flutter window (show/hide from tray click), the window sometimes appears behind other active windows instead of focusing in front. A known workaround exists but is awkward: temporarily set `alwaysOnTop = true`, then immediately set it back to `false`. This creates a visible flash or flicker.

**How to avoid:**
```dart
await windowManager.show();
await windowManager.focus();
// Workaround for z-order bug:
await windowManager.setAlwaysOnTop(true);
await Future.delayed(const Duration(milliseconds: 50));
await windowManager.setAlwaysOnTop(false);
```
The delay is necessary — setting `alwaysOnTop` and immediately unsetting it in the same event loop tick has no effect.

**Warning signs:**
- Window appears but is behind Terminal or another app
- Clicking the tray icon does not bring the window to front

**Phase to address:** Phase 1 (Foundation/Setup).

---

### Pitfall 11: State Management Over-Engineering — Riverpod Providers for Everything

**What goes wrong:** Flutter desktop apps are not mobile apps with complex navigation stacks. Pro Orc is a single-view dashboard. Developers coming from React often map the entire state to providers, creating a web of `StateNotifierProvider`, `FutureProvider`, and `StreamProvider` for every piece of data. This creates:
- Unnecessary complexity for a single-user app with no network state
- Provider invalidation cascades that trigger excessive rebuilds
- Harder debugging when providers depend on each other

**How to avoid:**
- Use Riverpod for state that genuinely needs it: the filesystem watch stream, git status per project
- Use plain Dart classes and `setState` for local widget state
- Prefer `StreamProvider` over `StateNotifierProvider` for the file watcher — the watch stream IS the state
- Do not create a provider for every UI preference. Use simple `ValueNotifier` or `InheritedWidget` for theme/display toggles.

**Warning signs:**
- More than 10 providers for a single-view app
- Providers that only exist to hold a `bool`
- Calling `ref.invalidate()` in response to every file change

**Phase to address:** Phase 2 (State Architecture). Establish state ownership guidelines before building components.

---

### Pitfall 12: Entitlements Files Not Kept in Sync (Debug vs. Release)

**What goes wrong:** Flutter macOS generates two entitlement files: `DebugProfile.entitlements` and `Release.entitlements`. Developers add entitlements to `DebugProfile.entitlements` (because that's where debug tests run), forget to add the same to `Release.entitlements`, and the release build silently breaks. This is documented in the official Flutter macOS building guide and is the most common macOS-specific deployment bug.

Additionally: **never edit entitlements through Xcode's Capabilities UI**. The Xcode UI may create a new entitlements file and switch the build target to use it, leaving the original files unused and creating a confusing three-file situation.

**How to avoid:**
- Always edit entitlement files directly as XML in a text editor
- After adding any entitlement, immediately add the same key to BOTH files
- Add a comment at the top of each file noting the required sync: `<!-- KEEP IN SYNC WITH DebugProfile.entitlements -->`
- Test release builds (`flutter build macos`) before marking any feature complete

**Warning signs:**
- Feature works with `flutter run` but not in the built `.app`
- Strange `Operation not permitted` errors only in release builds
- Multiple `.entitlements` files in `macos/Runner/` (more than two = Xcode created one)

**Phase to address:** Phase 1 (Foundation/Setup). Establish the entitlement sync rule on day one.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `runInShell: true` without resolving git path | Works on dev machine | Fails on machines where `/bin/sh` doesn't source `/etc/paths` | MVP only — replace with explicit path resolution |
| Disabling sandbox entirely (`app-sandbox` = false) | Full filesystem access | Cannot distribute via App Store | Acceptable — Pro Orc is direct distribution only |
| Static sRGB color values instead of OKLCH runtime conversion | Fast to implement | Design drift if OKLCH values change | Acceptable if colors are stored as named constants |
| Single `StreamController` for all file watch events | Simpler architecture | Cannot filter by directory/type efficiently | Acceptable until there are 50+ projects being watched |
| `setState` for git status instead of Riverpod | Less boilerplate | Manual refresh triggers, no caching | MVP only — causes UX jank at scale |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `git` subprocess | Using `Process.run('git', ...)` without full path | Resolve git path at startup; use `runInShell: true` as fallback |
| `tray_manager` | Expecting it to provide a popover/Flutter UI panel | Tray manager handles the icon; window show/hide is separate via `window_manager` |
| `FileSystemEntity.watch()` | Assuming one event per file save | Always debounce; events may coalesce or arrive multiple times |
| Entitlements | Editing via Xcode Capabilities UI | Edit XML files directly; keep both files in sync |
| `BackdropFilter` | Setting sigma > 20 | Keep sigma 5–15; wrap in `RepaintBoundary` |
| OKLCH colors | Copying CSS values to Dart `Color()` | Pre-convert to sRGB hex; use `okcolor` package if runtime conversion needed |
| Hot reload | Expecting native Swift changes to hot reload | Native code changes always require full `flutter run` restart |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Multiple `BackdropFilter` widgets in scrollable list | Frame drops, raster thread > 16ms | Use static background, not per-card blur | 3+ blur panels simultaneously visible |
| File watch event triggering git status synchronously | UI freezes on bulk git operations | Debounce file events; run git in background isolate | On any `git checkout` touching 10+ files |
| `Process.run()` without timeout | App freezes indefinitely | Always use `.timeout()` wrapper | First git call on a slow/locked repo |
| Rebuilding entire widget tree on every file event | Jank on dashboard with 20+ project cards | Use `StreamProvider` scoped to individual project cards | 15+ projects being watched |
| Dart `watcher` package without debounce | Excessive git status calls, process contention | 350ms debounce minimum | Any bulk file operation |

---

## "Looks Done But Isn't" Checklist

- [ ] **Filesystem access:** Works with `flutter run` — verify it also works in `flutter build macos` built `.app`
- [ ] **git integration:** Works on dev machine — verify on a machine with only Homebrew git (no system git via Xcode CLT)
- [ ] **Tray icon:** Shows in menubar — verify clicking opens popover (not context menu), verify no Dock icon visible
- [ ] **Glassmorphism:** Looks correct on dev display — verify no white halo on dark background on external monitor
- [ ] **Entitlements:** Debug build works — verify `Release.entitlements` matches `DebugProfile.entitlements`
- [ ] **File watcher:** Single file change works — verify batch changes (10+ files changed by git) do not cause crash or missed events
- [ ] **Process timeout:** git calls work on fast machine — verify app does not hang when `git` is not found or repo is locked

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Sandbox blocking filesystem | LOW | Edit both `.entitlements` files, rebuild — no code changes |
| git PATH not found in release build | LOW | Add `runInShell: true` or resolve path at startup |
| Process hang on M1 debug | LOW | Add `.timeout()` wrappers; test in release mode |
| File watcher missing events | MEDIUM | Add debounce + polling fallback for directory changes |
| Menubar architecture wrong (tray vs window) | HIGH | Requires Swift AppDelegate rewrite — do this right in Phase 1 |
| BackdropFilter white halo throughout UI | MEDIUM | Wrap each in `ClipRRect` + `RepaintBoundary` — tedious but mechanical |
| OKLCH colors wrong throughout UI | MEDIUM | Pre-convert all values; update color constants file centrally |
| Entitlement debug/release mismatch discovered late | LOW-MEDIUM | Add missing entitlements to Release.entitlements; rebuild |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Sandbox/entitlements setup | Phase 1 (Foundation) | Run built `.app` before any other code |
| Menubar-only architecture (LSUIElement + AppDelegate) | Phase 1 (Foundation) | No Dock icon visible; tray icon opens popover |
| Entitlement debug/release sync | Phase 1 (Foundation) | `diff DebugProfile.entitlements Release.entitlements` |
| `window_manager` z-order workaround | Phase 1 (Foundation) | Tray click brings window to front reliably |
| `tray_manager` + `app_links` conflict | Phase 1 (Foundation) | All tray menu items trigger Dart callbacks |
| Platform channel hot reload limitation | Phase 1 (Foundation) | Team workflow documented |
| git PATH resolution in built app | Phase 2 (Git Integration) | Test on machine with Homebrew-only git |
| `Process.run()` hang/timeout | Phase 2 (Git Integration) | All git calls have `.timeout(Duration(seconds: 10))` |
| File watcher event coalescing | Phase 2 (Filesystem Watch) | Test with `git checkout` on 50-file branch |
| Dart watcher `isDirectory` assertion crash | Phase 2 (Filesystem Watch) | Trigger directory create events; app should not crash |
| State management over-engineering | Phase 2 (State Architecture) | Provider count reviewed before adding more |
| OKLCH color conversion | Phase 3 (UI/Theming) | Visual comparison between web and Flutter versions |
| BackdropFilter white halo | Phase 3 (UI/Theming) | Dark background with blur panel — no white halo |
| BackdropFilter performance | Phase 3 (UI/Theming) | Flutter DevTools raster thread < 8ms with blur panels |

---

## Sources

- Flutter macOS Building guide (official, verified): https://docs.flutter.dev/platform-integration/macos/building
- Flutter issue #95805 — Process hangs on M1 debug mode: https://github.com/flutter/flutter/issues/95805
- Dart SDK issue #38364 — PATH not resolved on macOS for Process: https://github.com/dart-lang/sdk/issues/38364
- Flutter issue #89837 — Process.run crashes built macOS app: https://github.com/flutter/flutter/issues/89837
- Flutter issue #66920 — FileSystemException cannot open file (sandbox): https://github.com/flutter/flutter/issues/66920
- Flutter issue #122796 — macOS app sandbox behavior with flutter run: https://github.com/flutter/flutter/issues/122796
- Dart SDK issue #62124 — macOS watcher omits directory create events: https://github.com/dart-lang/sdk/issues/62124
- dart-lang/watcher issue #79 — isDirectory assertion failure on macOS: https://github.com/dart-lang/watcher/issues/79
- Flutter issue #149368 — Impeller backdrop blur processes entire screen: https://github.com/flutter/flutter/issues/149368
- Flutter issue #143947 — Impeller blur artifacts at high sigma: https://github.com/flutter/flutter/issues/143947
- Flutter issue #173530 — BackdropFilter white halo on dark backgrounds: https://github.com/flutter/flutter/issues/173530
- Flutter issue #126353 — Impeller BackdropFilter performance degradation: https://github.com/flutter/flutter/issues/126353
- Flutter issue #113368 — Flutter crashes after tray menu interaction: https://github.com/flutter/flutter/issues/113368
- tray_manager package — app_links compatibility note: https://pub.dev/packages/tray_manager
- macOS menubar-only Flutter template: https://github.com/mynameiskenlee/flutter_macos_menubar_example
- Flutter wide gamut color migration guide: https://docs.flutter.dev/release/breaking-changes/wide-gamut-framework
- okcolor package (OKLCH to Flutter Color): https://pub.dev/packages/okcolor

---
*Pitfalls research for: Flutter macOS Desktop — Pro Orc Project Orchestration Dashboard*
*Researched: 2026-02-19*
