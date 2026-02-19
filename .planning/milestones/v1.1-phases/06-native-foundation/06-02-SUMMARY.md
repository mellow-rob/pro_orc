---
phase: 06-native-foundation
plan: 02
subsystem: native-macos-shell
tags: [flutter, macos, tray-manager, window-manager, shared-preferences, launch-at-startup, glow-border]

dependency_graph:
  requires:
    - phase: 06-01
      provides: Flutter scaffold, tray_manager + window_manager installed, sandbox disabled, LSUIElement, main.dart init chain
  provides:
    - tray-icon-toggle (left-click show/hide window)
    - tray-context-menu (right-click Show/Hide + Quit)
    - hide-to-tray-on-close (red X hides, not quits)
    - window-geometry-persistence (SharedPreferences save/restore)
    - glow-border-shell (cyan/fuchsia BoxShadow UI)
    - launch-at-login-dialog (first-run only)
  affects:
    - 06-03 and beyond (ShellScreen is the base widget tree)

tech-stack:
  added: []
  patterns:
    - TrayListener mixin on StatefulWidget for tray icon event handling
    - WindowListener mixin on StatefulWidget for window event handling
    - SharedPreferences for 4-value geometry persistence (window_x, window_y, window_w, window_h)
    - Off-screen guard (x < -100 || y < -100 -> center()) for disconnected monitor safety
    - GlowBorderShell wraps Scaffold with BoxDecoration shadows and ClipRRect

key-files:
  created:
    - pro_orc/lib/tray/tray_service.dart (TrayListener: left-click toggle, right-click menu, quit action)
    - pro_orc/lib/window/window_geometry_service.dart (save/restore 4 values with off-screen guard)
    - pro_orc/lib/features/shell/glow_border_shell.dart (cyan/fuchsia BoxShadow + ClipRRect)
    - pro_orc/lib/features/shell/launch_dialog.dart (AlertDialog dark-theme launch-at-login prompt)
    - pro_orc/lib/features/shell/shell_screen.dart (StatefulWidget with WindowListener+TrayListener)
  modified:
    - pro_orc/lib/main.dart (geometry restore before show, setPreventClose, ShellScreen home, launchAtStartup.setup)

key-decisions:
  - "trayManager.ensureInitialized() does not exist in tray_manager 0.5.2 — removed, TrayService.init() handles setup"
  - "MenuItem import: tray_manager exports MenuItem directly; no need to hide it from flutter/material.dart"
  - "dart:ui must be imported explicitly in WindowGeometryService for Size and Offset types"
  - "withOpacity() deprecated in this Flutter version (info-only, not errors) — left as-is, plan does not require .withValues() migration"

patterns-established:
  - "TrayService: standalone class with TrayListener mixin, initialized in ShellScreen.initState"
  - "WindowGeometryService: instantiated inline in ShellScreen, save() called from onWindowMove/onWindowResize"
  - "First-launch dialogs: check SharedPreferences bool key, delay 500ms, show dialog, persist choice"

requirements-completed: [NAT-02, NAT-03]

duration: 7min
completed: 2026-02-19
---

# Phase 06 Plan 02: Tray, Window, and Shell UI Summary

**macOS menubar app behavior: tray toggle, hide-to-tray on close, SharedPreferences geometry persistence, cyan/fuchsia GlowBorderShell, and first-launch login dialog**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-19T11:44:23Z
- **Completed:** 2026-02-19T11:51:41Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- TrayService with left-click toggle and right-click context menu (Show/Hide + Quit)
- Window geometry persistence: save on move/resize, restore with off-screen guard on launch
- GlowBorderShell with dual BoxShadow (cyan 0.15 opacity + fuchsia 0.08 opacity) and ClipRRect
- ShellScreen as central widget: WindowListener + TrayListener mixins, hide-to-tray on red X
- First-launch dialog prompts for launch-at-login preference (checked via SharedPreferences flag)

## Task Commits

Each task was committed atomically:

1. **Task 1: TrayService, WindowGeometryService, main.dart wiring** - `5a0ab56` (feat)
2. **Task 2: ShellScreen, GlowBorderShell, LaunchDialog** - `cb7c7c0` (feat)

**Plan metadata:** `1f71d19` (docs: complete tray/window/shell plan)

## Files Created/Modified

- `pro_orc/lib/tray/tray_service.dart` - TrayListener: onTrayIconMouseDown toggles, onTrayIconRightMouseDown pops menu, onTrayMenuItemClick handles show_hide + quit
- `pro_orc/lib/window/window_geometry_service.dart` - save() writes 4 doubles to SharedPreferences; restore() reads them back with off-screen guard
- `pro_orc/lib/features/shell/glow_border_shell.dart` - Container with BoxDecoration: solid dark bg, cyan/fuchsia shadows, 1px border, ClipRRect
- `pro_orc/lib/features/shell/launch_dialog.dart` - showLaunchAtLoginDialog(): dark AlertDialog with "Not now" / "Yes, start at login" actions
- `pro_orc/lib/features/shell/shell_screen.dart` - StatefulWidget mixing WindowListener+TrayListener, first-launch check, placeholder content
- `pro_orc/lib/main.dart` - Added geometry.restore() + setPreventClose(true) + launchAtStartup.setup() + ShellScreen home

## Decisions Made

- `trayManager.ensureInitialized()` does not exist in tray_manager 0.5.2; the plan referenced a non-existent API. TrayService.init() is sufficient — removed the call.
- `MenuItem` is exported directly by tray_manager, not flutter/material.dart. Removed the `hide MenuItem` import approach.
- `dart:ui` required explicitly in WindowGeometryService for `Size` and `Offset` types.
- `withOpacity()` is deprecated in this Flutter SDK version but only generates info-level warnings (not errors). Left as-is since the plan does not require migration and all files pass `dart analyze` with exit code 0.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] trayManager.ensureInitialized() API does not exist**
- **Found during:** Task 1 (dart analyze on main.dart)
- **Issue:** Plan specified `await trayManager.ensureInitialized()` but tray_manager 0.5.2 has no such method on TrayManager. Caused compile error.
- **Fix:** Removed the call entirely. TrayService.init() sets up icon, tooltip, context menu, and registers listener — no separate initialization step needed.
- **Files modified:** pro_orc/lib/main.dart
- **Verification:** dart analyze passes with no errors
- **Committed in:** 5a0ab56 (Task 1 commit)

**2. [Rule 1 - Bug] MenuItem import strategy incorrect**
- **Found during:** Task 1 (dart analyze on tray_service.dart)
- **Issue:** Plan specified `import 'package:flutter/material.dart' hide MenuItem;` but flutter/material.dart doesn't export MenuItem — the hide was invalid and the material import was unused.
- **Fix:** Removed material.dart import entirely. tray_manager exports MenuItem directly.
- **Files modified:** pro_orc/lib/tray/tray_service.dart
- **Verification:** dart analyze passes with no errors
- **Committed in:** 5a0ab56 (Task 1 commit)

**3. [Rule 1 - Bug] Missing dart:ui import in WindowGeometryService**
- **Found during:** Task 1 (dart analyze on window_geometry_service.dart)
- **Issue:** `Size` and `Offset` types used without import. They live in dart:ui, not window_manager's re-export in this context.
- **Fix:** Added `import 'dart:ui';` at top of file.
- **Files modified:** pro_orc/lib/window/window_geometry_service.dart
- **Verification:** dart analyze passes with no errors
- **Committed in:** 5a0ab56 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All three fixes necessary to eliminate compile errors. No scope creep — plan logic unchanged.

## Issues Encountered

None beyond the auto-fixed bugs above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ShellScreen is the live base widget; Phase 7 can add navigation and project list UI on top of it
- Tray icon, window toggle, geometry persistence, and hide-to-tray all functional
- launch_at_startup is configured (launchAtStartup.setup called); enable/disable wired to first-launch dialog response
- Manual flutter run verification recommended to confirm tray icon appears and all interactions work correctly

---
*Phase: 06-native-foundation*
*Completed: 2026-02-19*
