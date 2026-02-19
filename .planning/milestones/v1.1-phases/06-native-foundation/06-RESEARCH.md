# Phase 6: Native Foundation - Research

**Researched:** 2026-02-19
**Domain:** Flutter macOS menubar-only app — tray icon, window management, sandbox, custom window chrome
**Confidence:** HIGH (core stack), MEDIUM (glow border approach), LOW (launch-at-login build quirks)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Tray icon & menu
- Branded color icon — cyan circuit/node mark matching the n3urala1 theme (not monochrome SF Symbol)
- Right-click shows minimal menu: "Show/Hide Window" and "Quit"
- Tooltip on hover shows app name + status summary: "Pro Orc — 12 projects, 2 stale" (placeholder text until data layer exists)

#### Window behavior
- Default size on first launch: 800×600 (medium dashboard)
- First launch: centered on screen. After that: remember last position
- Window stays visible on focus loss — standard app behavior, not popover-style
- Freely resizable — no minimum enforced, user can drag to any size
- Window position and size persisted across sessions

#### App lifecycle
- First launch prompts "Start Pro Orc when you log in?" — user chooses
- Cmd+Q quits the app entirely (tray icon disappears, process exits)
- No global keyboard shortcut for toggle — tray icon only
- Closing window (red X): Claude's discretion on whether to hide-to-tray or quit

#### Window chrome
- Hidden title bar — content goes edge-to-edge, traffic lights float over content
- Subtle cyan/fuchsia glow border around window edge — on-brand with n3urala1
- No Dock icon — menubar-only app

### Claude's Discretion

- Close button (red X) behavior: hide to tray vs quit — pick the most natural macOS menubar app behavior
- Vibrancy: whether to use macOS blur-through or solid dark background — whatever works best with the n3urala1 dark theme
- Window corner rounding: default macOS vs extra — match what looks best with the theme
- Exact tray icon design (as long as it's a cyan-colored abstract mark)
- Loading/splash behavior on first launch

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NAT-01 | App runs as native macOS .app with menubar icon, no Dock icon | `tray_manager` 0.5.2 + `LSUIElement` in Info.plist + `NSApp.setActivationPolicy(.accessory)` in AppDelegate |
| NAT-02 | Click on menubar icon shows/hides main window | `tray_manager` `onTrayIconMouseDown` + `windowManager.show()` / `windowManager.hide()` |
| NAT-03 | Window position and size persisted between sessions | `window_manager` `getPosition`/`getSize` + `shared_preferences` 2.5.4 + `WindowListener.onWindowMove/Resize` |
| NAT-04 | App Sandbox disabled for full filesystem + subprocess access | Set `com.apple.security.app-sandbox` to `false` in BOTH `Runner-DebugProfile.entitlements` AND `Runner-Release.entitlements` |
</phase_requirements>

---

## Summary

Phase 6 builds the native macOS shell for Pro Orc: a menubar-only app with tray icon, persistent window state, hidden title bar with custom glow border, and sandbox-free filesystem access. The Flutter ecosystem has a well-established, opinionated stack for this use case: `tray_manager` (0.5.2) and `window_manager` (0.5.1), both from the LeanFlutter organization (same author, compatible versions), plus `shared_preferences` for window geometry persistence.

The biggest risk is the two-entitlements-file trap: Flutter has separate `.entitlements` files for debug/profile and release builds. Disabling sandbox in only one means `flutter run` works but `flutter build macos` produces a sandboxed binary — which is exactly the silent failure mode the prior decisions flagged. Every sandbox change must be made in both files. The sandbox validation success criterion (NAT-04) must be tested against the `.app` bundle specifically.

The glow border is the one area without a direct Flutter package solution. The best path is implementing it as a Flutter `DecoratedBox` or `CustomPainter` layer rendered under the content — since the title bar is hidden and the window background can be made transparent via `window_manager`, the glow can be painted in Dart with `BoxShadow` or `BoxDecoration` using `BlurStyle.outer`. This keeps native Swift code minimal and is fully within Flutter's painting model. Vibrancy (blur-through) conflicts with a custom dark theme; recommend solid dark background with the glow border for maximum theme control.

**Primary recommendation:** Use `tray_manager` 0.5.2 + `window_manager` 0.5.1 + `shared_preferences` 2.5.4. Make all AppDelegate, Info.plist, and entitlement changes in the macos/ directory. Implement glow border in Flutter, not native Swift. Test sandbox with `flutter build macos` + direct `.app` launch, not `flutter run`.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tray_manager | ^0.5.2 | System tray icon, tooltip, context menu, click events | De-facto standard for Flutter desktop tray; same author as window_manager; actively maintained; latest: 0.5.2 (pub.dev, 3 months ago) |
| window_manager | ^0.5.1 | Window size/position control, title bar style, prevent-close intercept, show/hide | Comprehensive window control; 0.5.1 fixed macOS Sequoia PrivacyInfo warning; 0.5.0 added position APIs |
| shared_preferences | ^2.5.4 | Persist window geometry across sessions | Uses NSUserDefaults on macOS — reliable, zero-config, correct platform primitive |
| launch_at_startup | ^0.5.1 | "Start at login" toggle (first launch prompt + user preference) | LeanFlutter package, uses SMAppService on macOS 13+, SMLoginItemSetEnabled on older |
| macos_window_utils | ^1.9.1 | macOS-specific window tweaks: title bar transparency, traffic lights, material/vibrancy | Verified publisher (macosui.dev); 1.9.1 published 44 days ago; needed for titlebar transparency alongside window_manager |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_acrylic | latest | Window acrylic/blur/transparency effects | Only if vibrancy chosen over solid background (Claude's discretion; recommend solid dark instead) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tray_manager | system_tray | system_tray less actively maintained, different API surface |
| shared_preferences | sqflite / hive | Overkill for 4 numeric values (x, y, width, height) |
| Flutter-painted glow | Native NSWindow border Swift code | Swift approach is more complex, harder to theme dynamically |
| macos_window_utils | bitsdojo_window | bitsdojo_window older, less active; macos_window_utils has dedicated macOS focus |

**Installation:**
```bash
flutter pub add tray_manager window_manager shared_preferences launch_at_startup macos_window_utils
```

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── main.dart                    # ensureInitialized chain, WindowOptions, runApp
├── app/
│   ├── app.dart                 # MaterialApp root, dark theme
│   └── app_window.dart          # WindowListener mixin, geometry persistence logic
├── tray/
│   └── tray_manager_service.dart  # TrayListener, icon init, menu setup, show/hide toggle
├── window/
│   └── window_geometry_service.dart  # load/save position+size via shared_preferences
└── features/
    └── shell/
        └── shell_screen.dart    # Main window content: glow border + placeholder UI
macos/
├── Runner/
│   ├── AppDelegate.swift        # applicationShouldTerminateAfterLastWindowClosed → false
│   ├── Info.plist               # LSUIElement = true
│   ├── Runner-DebugProfile.entitlements  # com.apple.security.app-sandbox = false
│   └── Runner-Release.entitlements      # com.apple.security.app-sandbox = false (BOTH required)
└── Runner.xcodeproj/
    └── ...
assets/
└── images/
    └── tray_icon.png            # Cyan branded mark, ~22px, non-template (color preserved)
```

### Pattern 1: Initialization Chain in main()

**What:** All platform-level initialization must happen before `runApp()`, in a specific order.

**When to use:** Always — this is the required pattern for desktop Flutter with window_manager + tray_manager.

**Example:**
```dart
// Source: window_manager quick-start docs (leanflutter.dev)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await trayManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(800, 600),      // First launch default
    center: true,               // First launch: centered
    backgroundColor: Colors.transparent,
    skipTaskbar: true,          // No Dock icon (belt + suspenders with LSUIElement)
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Apply saved geometry if this is not first launch
    await _restoreWindowGeometry();
    await windowManager.show();
    await windowManager.focus();
  });

  await _initTray();
  runApp(const ProOrcApp());
}
```

### Pattern 2: Tray Setup with Left-Click Toggle

**What:** Left-click on tray icon shows/hides window. Right-click shows context menu.

**When to use:** Standard menubar app behavior — show/hide on click, right-click menu as secondary path.

**Example:**
```dart
// Source: tray_manager pub.dev docs
import 'package:flutter/material.dart' hide MenuItem;
import 'package:tray_manager/tray_manager.dart';

Future<void> _initTray() async {
  await trayManager.setIcon('assets/images/tray_icon.png');
  await trayManager.setToolTip('Pro Orc — 12 projects, 2 stale');

  final menu = Menu(items: [
    MenuItem(key: 'show_hide', label: 'Show/Hide Window'),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: 'Quit'),
  ]);
  await trayManager.setContextMenu(menu);
}

// In your State class:
class _AppState extends State<App> with TrayListener {
  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();
  }

  @override
  void onTrayIconMouseDown() async {
    // Left-click: toggle
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    // Right-click: show context menu (handled automatically by tray_manager)
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_hide':
        if (await windowManager.isVisible()) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.focus();
        }
      case 'quit':
        await windowManager.destroy(); // Hard exit, removes tray
    }
  }
}
```

### Pattern 3: Hide-to-Tray on Window Close (Red X)

**What:** Intercept window close, hide instead of quit. This is the natural macOS menubar app behavior — red X = hide, Cmd+Q = quit. Most macOS menubar apps (Bartender, Lungo, etc.) use this pattern.

**Decision for Claude's discretion:** Use hide-to-tray. Quitting on red X would make the tray icon disappear, which is disorienting for a menubar app. Users learn quickly that Cmd+Q is the "real" quit.

**Requires:** AppDelegate.swift change + `setPreventClose(true)` + `WindowListener.onWindowClose`.

**Example:**
```dart
// Source: window_manager quick-start docs
class _AppState extends State<App> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    windowManager.setPreventClose(true); // Must be called after ensureInitialized
    super.initState();
  }

  @override
  void onWindowClose() async {
    // Hide instead of close — natural menubar app behavior
    await windowManager.hide();
    // Do NOT call windowManager.close() here
  }
}
```

```swift
// macos/Runner/AppDelegate.swift — REQUIRED for hide to work
override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
  return false  // Without this, hiding the window quits the app
}
```

### Pattern 4: Window Geometry Persistence

**What:** Save position and size on every change, restore on launch.

**When to use:** Always — this is NAT-03.

**Example:**
```dart
// Source: window_manager API docs + shared_preferences docs
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class WindowGeometryService {
  static const _keyX = 'window_x';
  static const _keyY = 'window_y';
  static const _keyW = 'window_w';
  static const _keyH = 'window_h';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await prefs.setDouble(_keyX, pos.dx);
    await prefs.setDouble(_keyY, pos.dy);
    await prefs.setDouble(_keyW, size.width);
    await prefs.setDouble(_keyH, size.height);
  }

  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    if (x == null) return false; // First launch — use defaults

    final y = prefs.getDouble(_keyY)!;
    final w = prefs.getDouble(_keyW)!;
    final h = prefs.getDouble(_keyH)!;

    await windowManager.setSize(Size(w, h));
    await windowManager.setPosition(Offset(x, y));
    return true;
  }
}

// In WindowListener:
@override
void onWindowMove() => _geometryService.save();

@override
void onWindowResize() => _geometryService.save();
```

**Note:** `shared_preferences` writes are async and not guaranteed before process exit. For window geometry this is acceptable — worst case is losing the last resize/move, not data corruption. Save on every event rather than only on close to mitigate.

### Pattern 5: Hidden Title Bar with Glow Border

**What:** Use `TitleBarStyle.hidden` from window_manager + transparent window background + Flutter-painted glow border overlay.

**Decision for Claude's discretion — Vibrancy:** Use solid dark background, not vibrancy/blur. Vibrancy makes the background color dependent on what's behind the window, which undermines a custom dark theme. The n3urala1 dark theme needs predictable, controlled colors. Solid dark is correct here.

**Decision for Claude's discretion — Corner rounding:** Use default macOS window rounding. Adding extra rounding requires clipping the Flutter view and is complex without clear benefit.

**Example:**
```dart
// Glow border implemented as a Flutter widget wrapping all content
class GlowBorderShell extends StatelessWidget {
  final Widget child;
  const GlowBorderShell({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Subtle cyan/fuchsia glow — not neon, just presence
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.15), // cyan
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFFF00FF).withOpacity(0.08), // fuchsia accent
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
```

```dart
// main.dart — make window background transparent so glow renders correctly
WindowOptions windowOptions = WindowOptions(
  size: Size(800, 600),
  backgroundColor: Colors.transparent, // Required for glow
  titleBarStyle: TitleBarStyle.hidden,
  skipTaskbar: true,
);
```

```dart
// macos_window_utils — make title bar transparent so content fills edge-to-edge
WindowManipulator.makeTitlebarTransparent();
WindowManipulator.enableFullSizeContentView();
```

### Pattern 6: No Dock Icon

**What:** Two-pronged approach — `LSUIElement` in Info.plist (static) + `NSApp.setActivationPolicy(.accessory)` in AppDelegate (dynamic, handles edge cases).

**Example:**
```xml
<!-- macos/Runner/Info.plist -->
<key>LSUIElement</key>
<true/>
```

```swift
// macos/Runner/AppDelegate.swift
override func applicationDidFinishLaunching(_ notification: Notification) {
  // Belt and suspenders: ensure accessory policy even if Info.plist is wrong
  NSApp.setActivationPolicy(.accessory)
  super.applicationDidFinishLaunching(notification)
}
```

### Pattern 7: Sandbox Disable for Filesystem Access

**What:** Set `com.apple.security.app-sandbox` to `false` in BOTH entitlement files.

**Critical:** The debug/profile and release files are separate. A bug in debug works fine; the same bug in release builds creates a sandboxed `.app` that throws `FileSystemException`. The success criterion (NAT-04) must be verified against `flutter build macos`, not `flutter run`.

**Example:**
```xml
<!-- macos/Runner/Runner-DebugProfile.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>

<!-- macos/Runner/Runner-Release.entitlements — MUST ALSO HAVE sandbox = false -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Verification command:**
```bash
flutter build macos
# Then:
open build/macos/Build/Products/Release/ProOrc.app
# Then test reading ~/project_orchestration/ — must not throw FileSystemException
```

### Pattern 8: Launch at Login — First Launch Prompt

**What:** On first launch, show an in-app dialog asking "Start Pro Orc when you log in?". Record the user's choice in `shared_preferences`. Never ask again. Toggle via `launch_at_startup`.

**Example:**
```dart
import 'package:launch_at_startup/launch_at_startup.dart';

Future<void> handleFirstLaunchPrompt() async {
  final prefs = await SharedPreferences.getInstance();
  final hasAsked = prefs.getBool('launch_at_login_asked') ?? false;
  if (hasAsked) return;

  // Show dialog...
  final userSaidYes = await showLaunchAtLoginDialog(context);
  await prefs.setBool('launch_at_login_asked', true);

  if (userSaidYes) {
    await launchAtStartup.enable();
  } else {
    await launchAtStartup.disable();
  }
}
```

**Setup required** (from pub.dev docs):
1. Add `LaunchAtLogin` Swift package in Xcode: `https://github.com/sindresorhus/LaunchAtLogin`
2. Add Run Script Build Phase with: `"${BUILT_PRODUCTS_DIR}/LaunchAtLogin_LaunchAtLogin.bundle/Contents/Resources/copy-helper-swiftpm.sh"`
3. In Xcode Build Settings: disable "User Script Sandboxing" (required even with sandbox fully disabled)

### Anti-Patterns to Avoid

- **Setting sandbox to false in only one entitlements file:** `flutter run` uses DebugProfile; release build uses Release. Changing only one produces incorrect sandbox behavior in production.
- **Calling `windowManager.close()` in `onWindowClose`:** This creates an infinite loop. Use `windowManager.hide()` instead.
- **Forgetting `WidgetsFlutterBinding.ensureInitialized()` before plugin init:** `tray_manager.ensureInitialized()` and `windowManager.ensureInitialized()` both require the binding to be ready.
- **Using `setAsFrameless()` when you want hidden title bar:** `setAsFrameless()` removes ALL window chrome including the border. Use `TitleBarStyle.hidden` instead — it hides the bar but keeps the standard macOS window frame.
- **Using vibrancy with a custom dark theme:** Vibrancy makes background color depend on the system/wallpaper behind the window. This breaks theme consistency. Use solid dark.
- **Not calling `windowManager.focus()` after `windowManager.show()`:** Window appears but may be behind other windows without focus.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| System tray icon + menu | Custom NSStatusItem Swift via MethodChannel | `tray_manager` 0.5.2 | Handles icon size variants, menu delegation, cross-platform event routing |
| Window geometry (size/position) | Custom NSWindow delegate Swift code | `window_manager` 0.5.1 | Already wraps all NSWindow calls; `getPosition`/`setPosition`/`getSize`/`setSize` are stable APIs |
| Launch at login | Direct SMAppService Swift calls | `launch_at_startup` 0.5.1 | Handles macOS 12 vs 13+ API differences automatically; Xcode build phase complexity handled by package |
| Title bar hiding | Custom NSWindow subclass | `window_manager` `TitleBarStyle.hidden` + `macos_window_utils` `makeTitlebarTransparent()` | Handles multiple edge cases with NSWindow content layout guides |

**Key insight:** The LeanFlutter packages (`tray_manager`, `window_manager`, `launch_at_startup`) are designed as a coordinated suite. They use compatible initialization patterns and share event infrastructure. Using them together avoids conflicts that arise from mixing packages from different authors.

---

## Common Pitfalls

### Pitfall 1: Two Entitlements Files — The Debug/Release Trap
**What goes wrong:** Sandbox is disabled in `Runner-DebugProfile.entitlements` but not `Runner-Release.entitlements`. App works in `flutter run` but throws `FileSystemException` from the built `.app`.
**Why it happens:** Flutter applies different entitlement files based on build mode. This is not obvious because the file names suggest "Debug" and "Profile" specifically, not "everything except Release".
**How to avoid:** Always edit BOTH entitlement files. Cross-check: `grep -l "app-sandbox" macos/Runner/*.entitlements` should show two files with matching values.
**Warning signs:** NAT-04 success criterion only passes with `flutter run` and fails when opening the built `.app` directly.

### Pitfall 2: App Quits Instead of Hiding When Window Closes
**What goes wrong:** Calling `windowManager.hide()` in `onWindowClose` does nothing — the app quits anyway.
**Why it happens:** macOS default behavior: when the last window closes, the application terminates. `setPreventClose(true)` intercepts the Dart side, but if `AppDelegate.swift` returns `true` from `applicationShouldTerminateAfterLastWindowClosed`, the native side terminates the process before Flutter handles it.
**How to avoid:** The AppDelegate change (`return false`) is not optional — it is required for hide-to-tray. Add it before writing any Dart hide logic.
**Warning signs:** `onWindowClose()` is never called, app exits silently.

### Pitfall 3: Tray Icon Shows as Black Square on macOS
**What goes wrong:** PNG icon renders as a solid black square in the menu bar.
**Why it happens:** macOS interprets PNG images as template images by default if they lack color data, or inverts them. `tray_manager` passes the PNG directly; macOS may auto-apply template rendering.
**How to avoid:** Use a full-color PNG (not black/white) for a branded color icon. The user has chosen a cyan colored mark, not a monochrome template — this is correct. Do NOT add `.isTemplate = true` to the NSStatusItem button. Test on both light and dark system menu bars.
**Warning signs:** Icon appears correctly in simulator/Xcode but wrong in the running app.

### Pitfall 4: Window Position Restored Off-Screen
**What goes wrong:** On next launch, window opens off-screen (user had moved it to a secondary monitor that's no longer connected).
**Why it happens:** Saved coordinates are screen-absolute. If the screen configuration changes, coordinates may be outside any visible screen.
**How to avoid:** After restoring position, clamp to visible screen bounds using `windowManager.getPosition()` cross-referenced with `MediaQuery.of(context).size`. Simple implementation: if position is off-screen, fall back to centered on primary screen.
**Warning signs:** Window "disappears" on launch; actually opened off-screen.

### Pitfall 5: Dock Icon Appears Briefly on Launch
**What goes wrong:** App briefly shows a Dock icon on launch before disappearing.
**Why it happens:** `LSUIElement` in Info.plist prevents the Dock icon, but some Flutter initialization sequences cause a brief `.regular` activation policy before the `.accessory` policy is applied.
**How to avoid:** Set `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching` in AppDelegate as the first line. `LSUIElement = true` in Info.plist is the declarative approach; the Swift call is the imperative backup.
**Warning signs:** Dock icon flashes on launch.

### Pitfall 6: launch_at_startup Build Script Fails with Xcode 15+
**What goes wrong:** Build fails with sandbox error from the copy-helper script.
**Why it happens:** Xcode 15 enabled "User Script Sandboxing" by default. The `launch_at_startup` build phase script is not sandbox-compliant.
**How to avoid:** In Xcode → Build Settings → "User Script Sandboxing" → set to `No`. This is required even when the app's entitlements sandbox is already disabled.
**Warning signs:** Build error referencing the LaunchAtLogin bundle copy script.

---

## Code Examples

### Complete main.dart skeleton
```dart
// Source: window_manager quick-start + tray_manager pub.dev
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await trayManager.ensureInitialized();

  final geometryService = WindowGeometryService();

  WindowOptions windowOptions = WindowOptions(
    size: const Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    final restored = await geometryService.restore();
    if (!restored) {
      await windowManager.center(); // First launch: center
    }
    await windowManager.show();
    await windowManager.focus();
  });

  await _initTray(geometryService);
  runApp(const ProOrcApp());
}
```

### Complete AppDelegate.swift
```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return false  // Required: prevent quit on window close
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)  // No Dock icon
    super.applicationDidFinishLaunching(notification)
  }
}
```

### Tray icon asset setup (pubspec.yaml)
```yaml
flutter:
  assets:
    - assets/images/tray_icon.png
```

Icon file should be a 22×22 (or @2x: 44×44) PNG with the cyan circuit mark on a transparent background. Color icon, not monochrome/template. Place at `assets/images/tray_icon.png` relative to project root.

### Sandbox entitlements (both files)
```xml
<!-- macos/Runner/Runner-DebugProfile.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>

<!-- macos/Runner/Runner-Release.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSStatusItem in Swift via MethodChannel | `tray_manager` Dart package | 2020+ | All tray logic in Dart; no custom Swift needed |
| NSWindow delegate in Swift for position | `window_manager` Dart package | 2021+ | All window management in Dart |
| `setAsFrameless()` for custom windows | `TitleBarStyle.hidden` + `macos_window_utils` | 2022+ | Hidden bar keeps window frame; frameless removes all chrome |
| SMLoginItemSetEnabled only | `launch_at_startup` (SMAppService on 13+, fallback to older API) | macOS 13 (2022) | Package handles API split transparently |
| Template (monochrome) tray icons | Color PNG icons supported | tray_manager 0.4+ | Branded color icons work; not forced to monochrome |

**Deprecated/outdated:**
- `bitsdojo_window`: Less active than `window_manager`; not recommended for new projects
- `system_tray`: Fewer updates than `tray_manager`; different API style
- Direct Swift MethodChannel for window management: No longer necessary; adds maintenance burden

---

## Claude's Discretion — Research Findings & Recommendations

### Close Button (Red X) Behavior
**Recommendation: Hide to tray.**

Every established macOS menubar app (Bartender, Lungo, CleanMyMac menubar widget, etc.) hides on red X and quits on Cmd+Q. Users of menubar apps have internalized this pattern. Quitting on red X would make the tray icon disappear, requiring a full app relaunch — this is a worse UX for a background utility. The implementation is well-supported by `window_manager`'s `setPreventClose` + `onWindowClose` pattern.

### Vibrancy vs Solid Dark Background
**Recommendation: Solid dark background.**

Vibrancy makes the window background partially transparent, showing a blurred version of whatever is behind it. This means the "background color" of the app is actually a composite of the n3urala1 theme color + whatever is on the user's desktop. On a light desktop with a photo wallpaper, the dark theme will look muddy and inconsistent. Solid dark background gives full control over colors, contrasts, and the glow border effect. Use `backgroundColor: const Color(0xFF0A0A0F)` (near-black with slight blue tint) as the window background.

If vibrancy is ever revisited in a later phase (e.g., for a sidebar panel), `macos_window_utils` and `flutter_acrylic` both support NSVisualEffectView materials.

### Window Corner Rounding
**Recommendation: Default macOS rounding.**

macOS Ventura+ applies a standard corner radius to all windows automatically. Adding extra rounding requires clipping the Flutter view content and managing the transparent corner rendering carefully. The default macOS radius (~9px) already looks premium on a dark window with the glow border. No extra work needed.

### Tray Icon Design
**Recommendation: 22×22 PNG, cyan (#00E5FF) circuit/node mark on transparent background, non-template.**

Do not set the image as a template image (`isTemplate = false`) — this preserves the cyan color in both light and dark system menu bars. Design at @2x (44×44px) for Retina. The icon should be recognizable at small size: a simple node-and-connection mark, not text. Place directly in `assets/images/tray_icon.png`.

### Loading/Splash Behavior on First Launch
**Recommendation: No splash screen — window appears immediately with a loading skeleton or the placeholder shell UI.**

macOS menubar apps do not use splash screens. The window should appear quickly. Since Phase 6 has no data layer, the content area is a placeholder — it can show the app name and phase status text immediately with no loading state. The "first launch" modal for launch-at-login can appear as a dialog overlaid on the window after a ~500ms delay (enough time for the window to be visible and focused first).

---

## Open Questions

1. **tray_manager macOS entitlements requirements**
   - What we know: tray_manager 0.5.1 added "sandbox detection for containerized environments" — suggesting some sandbox awareness
   - What's unclear: Whether specific entitlements are needed for NSStatusBar access when sandbox is fully disabled (vs. specific entitlements when sandbox is enabled)
   - Recommendation: Since sandbox is disabled entirely (NAT-04), no specific tray-related entitlement is expected. If tray fails to initialize, check whether `com.apple.security.automation.apple-events` or similar is needed — but unlikely.

2. **tray_manager left-click vs right-click behavior on macOS**
   - What we know: `onTrayIconMouseDown` fires on left-click; `onTrayIconRightMouseDown`/`Up` fire on right-click
   - What's unclear: Whether macOS auto-shows the context menu on right-click without `popUpContextMenu()` call, or whether manual invocation is always required
   - Recommendation: Always call `trayManager.popUpContextMenu()` in `onTrayIconRightMouseDown` explicitly; don't rely on automatic behavior.

3. **window_manager + macos_window_utils interaction**
   - What we know: Both packages modify NSWindow; macos_window_utils docs suggest it complements window_manager
   - What's unclear: Whether calling `makeTitlebarTransparent()` and `enableFullSizeContentView()` after `windowManager.ensureInitialized()` can cause ordering issues
   - Recommendation: Call `macos_window_utils` APIs inside `waitUntilReadyToShow` callback, after window is ready.

---

## Sources

### Primary (HIGH confidence)
- `pub.dev/packages/tray_manager` — version 0.5.2, API, setup, TrayListener mixin
- `pub.dev/packages/window_manager` — version 0.5.1, changelog, WindowManager class API
- `pub.dev/packages/shared_preferences` — version 2.5.4, macOS NSUserDefaults backing
- `pub.dev/packages/macos_window_utils` — version 1.9.1, titlebar/vibrancy APIs
- `pub.dev/packages/launch_at_startup` — version 0.5.1, macOS setup requirements
- `leanflutter.dev/documentation/window_manager/quick-start` — complete initialization pattern, AppDelegate.swift change, setPreventClose + onWindowClose
- `docs.flutter.dev/platform-integration/macos/building` — entitlements files, sandbox disable procedure

### Secondary (MEDIUM confidence)
- `pub.dev/documentation/window_manager/latest/window_manager/WindowManager-class.html` — method list (getPosition, setPosition, getSize, setSize, hide, show, setPreventClose)
- GitHub issue flutter/flutter#66920 — confirmed root cause: sandbox entitlements for FileSystemException; disabling sandbox (app-sandbox = false) is the workaround
- tray_manager pub.dev example — complete TrayListener pattern with onTrayIconMouseDown, onTrayMenuItemClick
- window_manager pub.dev API + quick-start — confirmed WindowOptions.titleBarStyle, skipTaskbar, backgroundColor
- blog.whidev.com/menu-bar-extra-flutter-macos-app — AppDelegate NSStatusItem pattern, macOS menubar app structure

### Tertiary (LOW confidence)
- WebSearch results on tray icon template vs color behavior — macOS auto-applies template rendering; recommend testing both modes
- WebSearch on launch_at_startup Xcode 15 "User Script Sandboxing" requirement — from pub.dev docs but not independently verified with a test project

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified on pub.dev with current versions and changelogs
- Architecture patterns: HIGH — initialization chain and AppDelegate patterns from official docs; hide-to-tray from window_manager quick-start
- Sandbox disable: HIGH — confirmed by Flutter official docs and GitHub issue thread
- Glow border approach: MEDIUM — Flutter BoxShadow approach is sound but not tested against this exact use case; may need iteration
- Launch at startup Xcode 15 build setting: LOW — mentioned in pub.dev docs but not independently verified

**Research date:** 2026-02-19
**Valid until:** 2026-04-01 (packages are in stable maintenance mode; check for minor version bumps before starting)
