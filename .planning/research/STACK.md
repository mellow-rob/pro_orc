# Stack Research

**Domain:** Flutter macOS native desktop app (Pro Orc v1.1 rewrite)
**Researched:** 2026-02-19
**Confidence:** MEDIUM-HIGH (pub.dev packages verified via WebSearch; exact latest patch versions LOW confidence without direct pub.dev access)

---

## Context: What This Stack Replaces

The v1.0 stack (Next.js 16 + chokidar + simple-git + Tailwind/shadcn) is being fully replaced. This document covers only the Flutter/Dart additions needed for the macOS native rewrite. Node.js, npm, and the web stack are discarded entirely.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter SDK | 3.29.x stable | Cross-platform UI framework targeting macOS desktop | Latest stable as of early 2026. macOS desktop is Tier 1 supported. Impeller is default on mobile; macOS uses Skia/Metal — stable for this use case. |
| Dart | 3.x (bundled with Flutter 3.29) | Language for all business logic | Bundled with Flutter. Strong typing, async/await, `dart:io` for filesystem/process ops — no additional runtime needed. |
| flutter_riverpod | ^3.2.1 | App-wide state management | Riverpod 3 is the 2025/2026 community consensus for medium-complexity Flutter apps. Compile-time safety, no BuildContext dependency, automatic disposal. Provider (predecessor) is deprecated-path. BLoC is overkill for a single-user dashboard. |
| riverpod_annotation | ^3.x | Code generation for Riverpod providers | Required companion to flutter_riverpod 3.x for `@riverpod` annotation-based provider generation. Reduces boilerplate dramatically. |
| build_runner | ^2.x (dev) | Code generation runner | Required to run `riverpod_annotation` and `freezed` generators. Dev dependency only. |

**Confidence:** HIGH for Flutter/Dart selection. MEDIUM for Riverpod 3.2.1 version (verified as current 3.x series but exact patch not confirmed without direct pub.dev access).

---

### macOS Desktop Integration

| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| tray_manager | ^0.5.0 | System tray / menu bar icon + context menu | The standard Flutter package for macOS status bar integration. Uses NSStatusBar/NSStatusItem natively. Actively maintained (updated November 2025). Supports click-to-show-window, right-click context menus, and dynamic icon updates. Cross-platform (Windows/Linux) but macOS is primary target. |
| window_manager | ^0.4.x | Main window control (show/hide, position, resize, frameless) | Required for the menubar-app pattern: hide window on launch, show on tray click, set window level. From leanflutter (same author as tray_manager — consistent API design). Updated October 2025. |

**Confidence:** MEDIUM-HIGH for tray_manager (well-established, 0.5.0 referenced in multiple 2025 sources). MEDIUM for window_manager version (updated October 2025 per search results, exact version not directly confirmed).

**Critical macOS entitlement note:** Using `Process.run()` for git CLI calls requires disabling App Sandbox. Edit both `macos/Runner/DebugProfile.entitlements` AND `macos/Runner/Release.entitlements` — set `com.apple.security.app-sandbox` to `false`. This means the app **cannot be distributed via the Mac App Store**. For an internal developer tool (Pro Orc), this is acceptable. Do not use App Sandbox + hardened runtime for this project.

---

### Filesystem Operations

| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| watcher | ^1.x | Directory/file watching for live updates | The canonical Dart package for filesystem watching. Maintained by the Dart team (dart-archive). Wraps native FSEvents on macOS for efficient, event-driven notifications. Replaces chokidar. Published ~January 2026 (10.5M downloads). |
| path | ^1.9.x | Platform-aware path manipulation | Dart team package. Use instead of string concatenation for paths. Handles macOS `/` separators, `join()`, `basename()`, `dirname()`. Required companion to all filesystem work. |
| path_provider | ^2.1.x | Locate standard macOS directories | Flutter first-party plugin. Returns `applicationDocumentsDirectory`, `applicationSupportDirectory`, etc. Needed to locate `~/` and standard macOS paths. macOS desktop supported. |

**Confidence:** HIGH for `watcher` (Dart team maintained, widely used). HIGH for `path` and `path_provider` (first-party Flutter packages).

**`dart:io` is sufficient for most FS ops.** `File`, `Directory`, `FileSystemEntity` are built into Dart's standard library. Only add `watcher` for the reactive watching layer — reading `.md` files, walking directory trees, and parsing text are all native `dart:io` operations.

---

### Git Integration

| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| git | ^2.x | Git CLI wrapper for Dart | Dart package (by kevmoo, maintained by Google tooling team). Wraps `git` CLI via `Process.run()`. Provides `GitDir` abstraction: `GitDir.fromExisting()`, `getCommits()`, `getBranchName()`. Last updated September 2025. Replaces simple-git. |

**Confidence:** MEDIUM — `git` package (pub.dev/packages/git) is well-established and Google-maintained. Exact version 2.x confirmed from pub.dev search results showing `git 1.2.0` in version history and the package being actively updated September 2025.

**Alternative: raw `dart:io` Process.run().** `Process.run('git', ['log', '--oneline', '-5'], workingDirectory: repoPath)` is a valid alternative that avoids the dependency entirely. For the Pro Orc use case (reading branch name, last commit message, status), raw process calls may be simpler than the `GitDir` abstraction. Use `git` package when you need structured commit objects; use raw `Process.run` for one-off queries.

**Subprocess sandbox requirement applies here.** The same entitlement change that allows `Process.run` for git also applies to shell subprocesses generally.

---

### Theming: OKLCH Colors + Glassmorphism

| Approach | Package | Why |
|----------|---------|-----|
| OKLCH color conversion | `oklch` (^0.0.2) or manual conversion | The `oklch` pub.dev package (by leandroozorioj) converts OKLCH P3 color space values to Flutter `Color`. Thin utility — handles the math so you don't need to. Alternatively, `okcolor` package covers OkLab/OkLCH conversions. |
| Theme definition | Flutter `ThemeData` + `ColorScheme` | Define the n3urala1 dark theme using `ThemeData.dark()` as base, override with OKLCH-derived `Color` objects. No additional package needed for theming structure. |
| Glassmorphism effects | Native Flutter `BackdropFilter` + `dart:ui ImageFilter.blur` | No package needed. `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: ...)` is the standard Flutter approach. The `glassmorphism` package on pub.dev is thin wrapper — use it directly for full control. |
| Gradient overlays | Native Flutter `LinearGradient`, `Container` + `BoxDecoration` | Combine with `BackdropFilter` for the frosted glass + color overlay effect. |

**Confidence:** MEDIUM for `oklch` package (exists on pub.dev, version 0.0.2, niche package — low maintenance risk but low popularity). HIGH for native `BackdropFilter` approach (documented Flutter API, macOS-tested).

**OKLCH → Flutter `Color` conversion (manual fallback):**
```dart
// If the oklch package is insufficient, convert manually at design time:
// Use https://oklch.com to get sRGB hex values for your OKLCH design tokens,
// then hardcode as Flutter Color constants. OKLCH is for design tooling;
// Flutter renders in sRGB at runtime regardless.
const Color cyanPrimary = Color(0xFF00E5FF);   // OKLCH(85% 0.18 200)
const Color fuchsiaAccent = Color(0xFFE040FB); // OKLCH(70% 0.22 310)
```
This avoids a niche dependency entirely. Recommended approach for Pro Orc.

**macOS Impeller status:** As of Flutter 3.27-3.29, Impeller is default on iOS/Android but NOT on macOS desktop — macOS uses Skia/Metal. `BackdropFilter` works correctly on macOS via Skia. No special configuration needed.

---

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| freezed | ^2.x | Immutable data classes with copyWith/equality | Use for project data models (ProjectCard, PhaseData, etc). Reduces boilerplate vs manual classes. Companion: `freezed_annotation` + `build_runner`. |
| json_serializable | ^6.x | JSON serialization code gen | Only add if reading/writing JSON config files. May not be needed if STATE.md/ROADMAP.md are parsed as text. |
| shared_preferences | ^2.3.x | Key-value persistence for app settings | Store user preferences (scan paths, window position). Uses NSUserDefaults on macOS. Use the new `SharedPreferencesAsync` API (non-deprecated since 2.3.0). |
| url_launcher | ^6.x | Open URLs in system browser | For any "open in browser" actions on project cards. macOS desktop supported. |

---

## Installation

```bash
# Create Flutter macOS desktop project
flutter create --platforms=macos pro_orc_flutter

# In pubspec.yaml, add dependencies:
flutter pub add flutter_riverpod riverpod_annotation
flutter pub add tray_manager window_manager
flutter pub add watcher path path_provider
flutter pub add git
flutter pub add freezed_annotation

# Dev dependencies
flutter pub add --dev build_runner riverpod_generator freezed

# Optional (see theming section — may prefer manual OKLCH conversion)
flutter pub add oklch
```

**pubspec.yaml dependencies block:**
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^3.0.0

  # macOS desktop integration
  tray_manager: ^0.5.0
  window_manager: ^0.4.0

  # Filesystem
  watcher: ^1.0.0
  path: ^1.9.0
  path_provider: ^2.1.0

  # Git operations
  git: ^2.0.0

  # Data models
  freezed_annotation: ^2.0.0

  # Settings persistence
  shared_preferences: ^2.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  freezed: ^2.4.0
```

---

## macOS-Specific Configuration Required

### 1. Entitlements (CRITICAL — required for git/process operations)

`macos/Runner/DebugProfile.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- DISABLE sandbox to allow git subprocess calls -->
  <key>com.apple.security.app-sandbox</key>
  <false/>
  <!-- Keep these for debug/dev -->
  <key>com.apple.security.network.server</key>
  <true/>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
</dict>
</plist>
```

Apply the same sandbox disable to `macos/Runner/Release.entitlements`. Without this, `Process.run('git', ...)` will throw `ProcessException: Operation not permitted`.

### 2. Info.plist (macOS deployment target)

Ensure `macos/Runner/Info.plist` has at minimum macOS 10.14.6 deployment target (required by `macos_ui` if used; `tray_manager` requires macOS 10.11+).

### 3. tray_manager setup (AppDelegate.swift)

```swift
// macos/Runner/AppDelegate.swift
import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return false  // REQUIRED: keep app alive when main window closes
  }
}
```

Without `return false`, closing the main window quits the app — defeating the menubar-app pattern.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| State management | Riverpod 3.x | BLoC | BLoC is excellent for large teams but adds Streams/Events/States boilerplate for a single-developer dashboard. Riverpod providers + `ref.watch` is simpler. |
| State management | Riverpod 3.x | Provider (flutter_provider) | Provider is the predecessor to Riverpod. The Flutter team now recommends Riverpod. Provider doesn't have compile-time safety. |
| State management | Riverpod 3.x | setState / InheritedWidget | Workable for small widgets but doesn't scale to cross-widget state (tray events → UI updates). |
| Tray integration | tray_manager | system_tray | system_tray (pub.dev) exists but tray_manager has more active maintenance and cleaner API. Both use NSStatusBar natively. |
| Tray integration | tray_manager | Custom macOS plugin | Viable (Flutter plugins with AppKit are straightforward) but unnecessary given tray_manager's quality. |
| File watching | watcher | dart:io FileSystemEntity.watch | `FileSystemEntity.watch()` is built-in but doesn't handle recursive directory trees well on macOS. `watcher` wraps FSEvents for reliable recursive watching — same reason chokidar existed in Node.js. |
| Git operations | git package | process_run package | `process_run` is a heavier utility for shell scripting. For git specifically, the `git` package's `GitDir` abstraction is cleaner. Raw `dart:io Process.run` is fine for simple one-shot calls. |
| Git operations | git package | libgit2 (dart binding) | No maintained Dart binding for libgit2. Not viable. |
| OKLCH theming | Manual hex constants | oklch pub.dev package | The `oklch` package at v0.0.2 is low-popularity. Converting OKLCH to sRGB at design time (via oklch.com) and hardcoding Flutter Color constants is simpler, zero-dependency, and maintainable. |
| Glassmorphism | Native BackdropFilter | glassmorphism package | The package is a thin wrapper around BackdropFilter — adds nothing you can't do in 10 lines. Own the code. |
| macOS UI widgets | Flutter Material widgets | macos_ui package | macos_ui (v2.1.10, updated Oct 2025) provides native macOS-look widgets. BUT the Pro Orc design spec calls for the custom n3urala1 dark theme (glassmorphism, OKLCH cyan/fuchsia) — not native macOS HIG appearance. Don't use macos_ui; use Material widgets styled to match the design. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| macos_ui package | Imposes native macOS HIG styling (sidebars, toolbars) that conflicts with the custom n3urala1 glassmorphism design. You'd spend more time fighting the widget system than using it. | Flutter Material widgets + custom ThemeData |
| GetX | All-in-one framework (state + routing + DI) with global state patterns that make testing hard. Large footprint for minimal gain vs Riverpod. | Riverpod for state, Navigator 2.0 for routing |
| flutter_bloc | Not wrong, just more ceremony than this project needs. Every feature requires Event/State/Bloc classes. | Riverpod AsyncNotifier/Notifier |
| Hive / Isar / SQLite (drift) | The filesystem IS the database for Pro Orc — scanning .md files is the data layer. Adding a local DB creates a sync problem (cache invalidation from external filesystem changes). | `dart:io` + `watcher` |
| flutter_gen (asset codegen) | Useful for large apps with many assets. Pro Orc is a minimal tool app — manual asset references are fine. | String asset paths directly |
| auto_route / go_router | Pro Orc is a single-window app with minimal navigation. Simple Navigator.push or a top-level state variable for "current view" is sufficient. | Built-in Navigator or conditional widget rendering |
| Impeller opt-in flags for macOS | Impeller is not yet default on macOS desktop. Forcing it on may cause visual artifacts or performance regressions. Wait for Flutter team to enable by default. | Default Skia/Metal rendering (no flag needed) |
| App Sandbox (for distribution) | Disabling sandbox (required for git subprocess) means no Mac App Store distribution. This is intentional for a developer tool — don't try to re-enable sandbox and work around it. | Distribute as direct download / Homebrew cask |

---

## Version Compatibility

| Package | Compatible Flutter Version | Notes |
|---------|---------------------------|-------|
| tray_manager ^0.5.0 | Flutter 3.3+ / Dart 3.0+ | Minimum SDK bump in recent changelog |
| window_manager ^0.4.x | Flutter 3.x | Same leanflutter ecosystem as tray_manager |
| watcher ^1.0.0 | Dart 2.12+ (null-safe) | Dart team package, stable |
| flutter_riverpod ^3.2.1 | Flutter 3.x / Dart 3.x | Riverpod 3 requires Dart 3 for records/patterns |
| git ^2.x | Dart 2.19+ | Google-maintained, stable |
| path_provider ^2.1.x | Flutter 3.x | First-party Flutter plugin |

---

## Sources

- pub.dev/packages/tray_manager — tray_manager 0.5.0, updated November 2025 (WebSearch, MEDIUM confidence)
- pub.dev/packages/window_manager — window_manager, updated October 2025 (WebSearch, MEDIUM confidence)
- pub.dev/packages/watcher — watcher Dart team package, published ~January 2026, 10.5M downloads (WebSearch, MEDIUM confidence)
- pub.dev/packages/git — git package by kevmoo/Google, updated September 2025, GitDir abstraction (WebSearch, MEDIUM confidence)
- pub.dev/packages/flutter_riverpod — flutter_riverpod ^3.2.1 current series, Riverpod 3.0 released (WebSearch, MEDIUM confidence)
- pub.dev/packages/oklch — oklch 0.0.2 OKLCH→Flutter Color conversion (WebSearch, LOW confidence — niche package)
- pub.dev/packages/macos_ui — macos_ui 2.1.10, October 2025 (WebSearch, MEDIUM confidence; explicitly NOT recommended)
- Flutter macOS desktop docs: https://docs.flutter.dev/platform-integration/macos/building — App Sandbox entitlement requirements (WebSearch, HIGH confidence)
- Flutter Impeller docs: https://docs.flutter.dev/perf/impeller — macOS not yet Impeller-default (WebSearch, MEDIUM confidence)
- riverpod.dev/docs/whats_new — Riverpod 3.0 release and features (WebSearch, MEDIUM confidence)
- GitHub github.com/leanflutter/tray_manager — NSStatusBar/NSStatusItem implementation approach (WebSearch, MEDIUM confidence)
- GitHub github.com/mynameiskenlee/flutter_macos_menubar_example — applicationShouldTerminateAfterLastWindowClosed pattern (WebSearch, MEDIUM confidence)

---
*Stack research for: Flutter macOS native desktop (Pro Orc v1.1 rewrite)*
*Researched: 2026-02-19*
