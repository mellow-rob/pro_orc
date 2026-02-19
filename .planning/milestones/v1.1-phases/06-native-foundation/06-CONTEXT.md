# Phase 6: Native Foundation - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Flutter macOS menubar-only app with tray icon, show/hide window on click, persist window position/size, and sandbox-free filesystem access in a built .app bundle. No project data, no scanning, no UI content — just the native shell.

</domain>

<decisions>
## Implementation Decisions

### Tray icon & menu
- Branded color icon — cyan circuit/node mark matching the n3urala1 theme (not monochrome SF Symbol)
- Right-click shows minimal menu: "Show/Hide Window" and "Quit"
- Tooltip on hover shows app name + status summary: "Pro Orc — 12 projects, 2 stale" (placeholder text until data layer exists)

### Window behavior
- Default size on first launch: 800×600 (medium dashboard)
- First launch: centered on screen. After that: remember last position
- Window stays visible on focus loss — standard app behavior, not popover-style
- Freely resizable — no minimum enforced, user can drag to any size
- Window position and size persisted across sessions

### App lifecycle
- First launch prompts "Start Pro Orc when you log in?" — user chooses
- Cmd+Q quits the app entirely (tray icon disappears, process exits)
- No global keyboard shortcut for toggle — tray icon only
- Closing window (red X): Claude's discretion on whether to hide-to-tray or quit

### Window chrome
- Hidden title bar — content goes edge-to-edge, traffic lights float over content
- Subtle cyan/fuchsia glow border around window edge — on-brand with n3urala1
- No Dock icon — menubar-only app

### Claude's Discretion
- Close button (red X) behavior: hide to tray vs quit — pick the most natural macOS menubar app behavior
- Vibrancy: whether to use macOS blur-through or solid dark background — whatever works best with the n3urala1 dark theme
- Window corner rounding: default macOS vs extra — match what looks best with the theme
- Exact tray icon design (as long as it's a cyan-colored abstract mark)
- Loading/splash behavior on first launch

</decisions>

<specifics>
## Specific Ideas

- Tray icon should feel like a small branded mark, not a generic system icon
- The glow border should be subtle — not neon, just enough to give the window presence on a dark desktop
- Hidden title bar with floating traffic lights gives the app a premium, custom feel

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-native-foundation*
*Context gathered: 2026-02-19*
