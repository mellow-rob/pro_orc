---
phase: 06-native-foundation
plan: 01
subsystem: native-macos-shell
tags: [flutter, macos, tray, window-manager, sandbox, entitlements]
dependency_graph:
  requires: []
  provides:
    - flutter-project-scaffold
    - macos-native-config
    - dependency-chain
    - tray-icon-asset
  affects:
    - 06-02-tray-window (builds on this scaffold)
    - all subsequent phase-06 plans
tech_stack:
  added:
    - flutter 3.41.1 (via homebrew cask /opt/homebrew/share/flutter)
    - tray_manager 0.5.2
    - window_manager 0.5.1
    - shared_preferences 2.5.4
    - launch_at_startup 0.5.1
    - macos_window_utils 1.9.1
  patterns:
    - Flutter initialization chain (WidgetsFlutterBinding + windowManager.ensureInitialized)
    - macOS accessory policy (no Dock icon via LSUIElement + setActivationPolicy)
    - Sandbox-disabled entitlements (both DebugProfile and Release)
key_files:
  created:
    - pro_orc/pubspec.yaml (Flutter project + 5 dependencies + asset declaration)
    - pro_orc/lib/main.dart (initialization chain with hidden title bar)
    - pro_orc/assets/images/tray_icon.png (44x44 cyan circle PNG)
    - pro_orc/macos/Runner/DebugProfile.entitlements (sandbox disabled)
    - pro_orc/macos/Runner/Release.entitlements (sandbox disabled)
  modified:
    - pro_orc/macos/Runner/AppDelegate.swift (no Dock icon, no quit on window close)
    - pro_orc/macos/Runner/Info.plist (LSUIElement = true)
decisions:
  - "Use DebugProfile.entitlements / Release.entitlements (not Runner- prefix) — Flutter 3.41.1 generates without prefix"
  - "Re-added applicationSupportsSecureRestorableState override to AppDelegate (secure state restoration best practice)"
  - "Flutter installed via homebrew cask at /opt/homebrew/share/flutter — existing PATH in .zshrc pointed to missing /Users/rob/code/flutter"
metrics:
  duration: 14 minutes
  completed: 2026-02-19
  tasks_completed: 2
  files_created: 40
  deviations: 3
---

# Phase 06 Plan 01: Native Foundation Scaffold Summary

Flutter macOS project with sandbox-disabled entitlements, menubar-only app config, window_manager + tray_manager initialization chain, and verified `flutter build macos` success.

## What Was Built

A complete Flutter macOS project scaffold at `pro_orc/` that forms the native foundation for all subsequent plans in Phase 6. The app launches without a Dock icon (LSUIElement + accessory policy), has sandbox disabled in both build configurations, and uses window_manager's hidden title bar style. `flutter build macos` produces a 39.1MB `.app` bundle.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Flutter project creation + macOS native config | 85b0c44 | pubspec.yaml, AppDelegate.swift, Info.plist, DebugProfile.entitlements, Release.entitlements |
| 2 | main.dart init chain + tray icon asset + build | ae831d0 | lib/main.dart, assets/images/tray_icon.png, pubspec.yaml |

## Verification Results

1. `flutter pub get` — PASS (all 5 deps resolved: tray_manager 0.5.2, window_manager 0.5.1, shared_preferences 2.5.4, launch_at_startup 0.5.1, macos_window_utils 1.9.1)
2. Sandbox disabled in both entitlement files — PASS (`<false/>` in both DebugProfile and Release)
3. LSUIElement = true in Info.plist — PASS
4. AppDelegate has `applicationShouldTerminateAfterLastWindowClosed` returns false — PASS
5. AppDelegate has `setActivationPolicy(.accessory)` — PASS
6. `flutter build macos` succeeds — PASS (39.1MB build/macos/Build/Products/Release/pro_orc.app)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Environment] Flutter not installed at expected path**
- **Found during:** Pre-task setup
- **Issue:** `.zshrc` PATH referenced `/Users/rob/code/flutter/bin` which did not exist. `flutter` not in PATH.
- **Fix:** Flutter 3.41.1 was already being downloaded via `brew install --cask flutter` (concurrent background process). Waited for download (~2GB), then used flutter binary at `/opt/homebrew/share/flutter/bin/flutter`.
- **Impact:** No plan changes needed — used direct binary path for all commands.

**2. [Rule 1 - Bug] Entitlement file names differ from plan**
- **Found during:** Task 1 — reading generated files
- **Issue:** Plan referenced `Runner-DebugProfile.entitlements` and `Runner-Release.entitlements`, but Flutter 3.41.1 generates `DebugProfile.entitlements` and `Release.entitlements` (no `Runner-` prefix)
- **Fix:** Edited the actual generated files (without prefix). Must_haves artifact paths in plan were historical — actual behavior is correct.
- **Files modified:** `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`

**3. [Rule 2 - Critical] Re-added applicationSupportsSecureRestorableState**
- **Found during:** Task 2 — `flutter build macos` warning
- **Issue:** Flutter build warned that removing `applicationSupportsSecureRestorableState` from AppDelegate requires migration. This method enables secure state restoration on macOS.
- **Fix:** Added `override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { return true }` back to AppDelegate after the plan's required overrides.
- **Files modified:** `macos/Runner/AppDelegate.swift`
- **Commit:** ae831d0

## Self-Check: PASSED

All created files verified to exist on disk. Both task commits (85b0c44, ae831d0) confirmed in git log. .app bundle exists at `pro_orc/build/macos/Build/Products/Release/pro_orc.app`.
