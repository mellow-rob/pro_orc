# Roadmap: Pro Orc — Project Orchestration Dashboard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-02-19)
- 🚧 **v1.1 Flutter macOS Rewrite** — Phases 6-11 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-02-19</summary>

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-02-17
- [x] Phase 2: Data Layer (3/3 plans) — completed 2026-02-17
- [x] Phase 3: Static Dashboard (2/2 plans) — completed 2026-02-17
- [x] Phase 4: Live Updates (2/2 plans) — completed 2026-02-17
- [x] Phase 5: Claude Tools (2/2 plans) — completed 2026-02-17

See: milestones/v1.0-ROADMAP.md for full details

</details>

### 🚧 v1.1 Flutter macOS Rewrite (In Progress)

**Milestone Goal:** Complete rewrite of the Next.js web dashboard as a native macOS Flutter app with full v1.0 feature parity, menubar tray icon, and reactive file-watching — no browser, no dev server.

- [ ] **Phase 6: Native Foundation** - Flutter macOS app with tray icon, show/hide window, entitlements, and no Dock icon
- [ ] **Phase 7: Data Layer** - Pure Dart filesystem scanner, GSD parser, and git reader with unit tests
- [ ] **Phase 8: Reactive State** - Riverpod providers + file watcher wired end-to-end; edits to STATE.md update the app live
- [ ] **Phase 9: Theme + UI Shell** - n3urala1 dark theme constants, glassmorphism pattern, and tab navigation scaffold
- [ ] **Phase 10: Card Widgets + Quick Actions** - All project cards, quick actions, and live-update chain verified end-to-end
- [ ] **Phase 11: Claude Tools Panel** - Tools tab fully functional with auto-discovered Skills, MCP servers, and Plugins

## Phase Details

### Phase 6: Native Foundation
**Goal**: The Flutter macOS app runs as a menubar-only app with tray icon, shows and hides the main window on click, persists window position, and passes a sandbox validation check in a built .app bundle
**Depends on**: Nothing (first phase of v1.1)
**Requirements**: NAT-01, NAT-02, NAT-03, NAT-04
**Success Criteria** (what must be TRUE):
  1. App launches with a tray icon in the macOS menubar and no Dock icon
  2. Clicking the tray icon shows the main window; clicking again hides it
  3. Window position and size are restored to the previous session's values on next launch
  4. A `flutter build macos` release build can read a file from `~/project_orchestration/` without throwing a FileSystemException (sandbox disabled)
**Plans:** 3 plans
Plans:
- [ ] 06-01-PLAN.md — Flutter project scaffold + macOS native config (entitlements, AppDelegate, Info.plist, dependencies)
- [ ] 06-02-PLAN.md — Tray service, window geometry persistence, glow border shell, launch-at-login
- [ ] 06-03-PLAN.md — Release build verification + human verification of all NAT requirements

### Phase 7: Data Layer
**Goal**: Pure Dart services can scan project directories, parse GSD planning files, and read git history — all verified with unit tests and without running the Flutter app
**Depends on**: Phase 6
**Requirements**: SCAN-01, SCAN-02, SCAN-03, SCAN-04, SCAN-05, GIT-01, GIT-02, GIT-03
**Success Criteria** (what must be TRUE):
  1. Scanner discovers all projects in `~/project_orchestration/code/` and `~/project_orchestration/project research/`, correctly classifying each as Code or Research type
  2. GSD parser extracts status, phase, progress percentage, and next step from a `.planning/` directory
  3. Notion URL and project description are extracted from `PROJECT.md` for any project that has them
  4. Git reader returns last commit message, hash, and timestamp for a code project; concurrent calls complete within 5 seconds with a timeout wrapper in place
  5. GitHub remote URL is correctly extracted from `git remote get-url origin`
**Plans**: TBD

### Phase 8: Reactive State
**Goal**: Editing any `.planning/` file causes the in-memory project data to update within one second, without restarting the app — the full watcher-to-provider-to-UI invalidation chain works
**Depends on**: Phase 7
**Requirements**: LIVE-01, LIVE-02, LIVE-03
**Success Criteria** (what must be TRUE):
  1. File watcher detects changes to `.planning/STATE.md` or `ROADMAP.md` and fires an event within 350ms debounce window
  2. Editing a `STATE.md` on disk causes the corresponding project's data to change in the running app without a hot reload or restart
  3. Multiple rapid file saves (e.g., auto-save bursts) result in exactly one data refresh, not N refreshes
**Plans**: TBD

### Phase 9: Theme + UI Shell
**Goal**: The app renders the n3urala1 dark theme with correct cyan/fuchsia colors, glassmorphism card backgrounds, atmospheric orbs, and a three-tab navigation bar — all before any card content is wired
**Depends on**: Phase 8
**Requirements**: UI-04, UI-05
**Success Criteria** (what must be TRUE):
  1. App displays three tabs: Code, Research, and Claude Tools — switching tabs shows the correct empty container for each
  2. Background renders atmospheric radial-gradient orbs (cyan and fuchsia) on a near-black surface
  3. A glassmorphism placeholder card shows correct blur, border, and no white halo artifact on the dark background
  4. All named color constants match the n3urala1 OKLCH design tokens (converted to sRGB hex)
**Plans**: TBD

### Phase 10: Card Widgets + Quick Actions
**Goal**: The Code and Research tabs display live project cards with all v1.0 data fields, quick action buttons work, and editing a planning file updates the card in real time
**Depends on**: Phase 9
**Requirements**: UI-01, UI-02, UI-03, UI-06, ACT-01, ACT-02, ACT-03, ACT-04
**Success Criteria** (what must be TRUE):
  1. Code tab shows a card for every discovered code project with name, GSD status badge, phase progress, next step, last git commit, and stale indicator
  2. Research tab shows a card for every research project with name and description, and no git metrics
  3. Quick action buttons open the correct app: Terminal.app opens to the project path, Finder reveals the folder, GitHub URL opens in the default browser, Notion URL opens in the default browser
  4. Private/visible toggle on a card hides it from the grid for the session without affecting other cards
  5. Editing a project's `STATE.md` causes its card to update within one second without restarting the app
**Plans**: TBD

### Phase 11: Claude Tools Panel
**Goal**: The Claude Tools tab displays auto-discovered Skills, MCP servers, and Plugins from `~/.claude/` with name, type, and description for each tool
**Depends on**: Phase 10
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04
**Success Criteria** (what must be TRUE):
  1. Claude Tools tab lists all Skills found in `~/.claude/` with correct name and description
  2. MCP servers and Plugins are discovered and displayed in distinct sections with their type labeled
  3. Adding a new skill file to `~/.claude/` and refreshing the app causes it to appear in the Tools tab
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-02-17 |
| 2. Data Layer | v1.0 | 3/3 | Complete | 2026-02-17 |
| 3. Static Dashboard | v1.0 | 2/2 | Complete | 2026-02-17 |
| 4. Live Updates | v1.0 | 2/2 | Complete | 2026-02-17 |
| 5. Claude Tools | v1.0 | 2/2 | Complete | 2026-02-17 |
| 6. Native Foundation | v1.1 | 0/3 | Planning complete | - |
| 7. Data Layer | v1.1 | 0/? | Not started | - |
| 8. Reactive State | v1.1 | 0/? | Not started | - |
| 9. Theme + UI Shell | v1.1 | 0/? | Not started | - |
| 10. Card Widgets + Quick Actions | v1.1 | 0/? | Not started | - |
| 11. Claude Tools Panel | v1.1 | 0/? | Not started | - |
