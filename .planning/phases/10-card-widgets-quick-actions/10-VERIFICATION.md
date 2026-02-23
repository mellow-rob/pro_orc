---
phase: 10-card-widgets-quick-actions
verified: 2026-02-23T07:30:43Z
status: human_needed
score: 7/8 must-haves verified
re_verification: false
human_verification:
  - test: "Run flutter run -d macos and verify Code tab shows cards for all code projects"
    expected: "Cards display name, version (if found), status badge, progress bar, next step, description, and quick action buttons. Cards are sorted by most recent git activity."
    why_human: "Visual rendering, actual data population, and sort order can only be confirmed in the running app."
  - test: "Resize the app window and observe column count change"
    expected: "Grid reflows: narrow -> 2 columns, medium -> 3, wide -> 4 columns. No overflow or clipping."
    why_human: "Responsive layout correctness requires visual inspection of rendered UI."
  - test: "Click Terminal button on a code card"
    expected: "Terminal.app opens at the project directory path."
    why_human: "Process.run side effect cannot be verified by static analysis."
  - test: "Click Finder button on a code card"
    expected: "Finder opens and reveals the project directory."
    why_human: "Process.run side effect requires running the app."
  - test: "Right-click a code card, select 'Privat', then quit and restart the app"
    expected: "The card is hidden after toggle. After restart it is still hidden (Drift persistence confirmed)."
    why_human: "DB persistence across restarts requires running the app twice."
  - test: "Click a card to open the detail panel"
    expected: "Modal slides up with fade animation. Shows all GSD data including full phases list with status icons/plan counts and decisions list. Dismisses on outside click."
    why_human: "Animation correctness, data population from gsd.phases and gsd.decisions, and dismiss behavior require visual/interactive verification."
  - test: "Edit a project's .planning/STATE.md (change status text) while app is running"
    expected: "The corresponding card updates within approximately one second without restarting the app."
    why_human: "Live update behavior depends on file system watcher timing in the running process."
  - test: "Switch to Research tab and verify fuchsia-accented cards for research projects"
    expected: "Research cards show fuchsia science icon, name, description. No progress bar, no status badge, no git metrics. Sort is alphabetical."
    why_human: "Visual differentiation and correct tab filtering require running the app with actual research projects."
---

# Phase 10: Card Widgets + Quick Actions Verification Report

**Phase Goal:** The Code and Research tabs display live project cards with all v1.0 data fields, quick action buttons work, and editing a planning file updates the card in real time
**Verified:** 2026-02-23T07:30:43Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Code tab shows a card for every discovered code project with name, GSD status badge, phase progress, next step, last git commit, and stale indicator | ? PARTIAL | Cards show name, badge, progress bar, next step — confirmed in code. Last git commit and stale indicator are deliberately excluded per locked decision in CONTEXT.md ("Kein Stale-Indikator — bewusst weggelassen", "Keine Commit-Message"). Git info available in detail panel. Card rendering itself needs human confirmation. |
| SC-2 | Research tab shows a card for every research project with name and description, and no git metrics | ? UNCERTAIN | ResearchProjectCard exists, shows name + description, no git fields. Research tab filters to projectType == 'research'. Fuchsia accent confirmed in code. Actual rendering needs human confirmation. |
| SC-3 | Quick action buttons open the correct app: Terminal.app, Finder, GitHub, Notion | ? UNCERTAIN | QuickActionsService wired with correct `open -a Terminal` and `open` commands, launchUrl for URLs. All four buttons wired to service in both card widgets. Actual execution requires running app. |
| SC-4 | Private/visible toggle on a card hides it from the grid for the session without affecting other cards | ? UNCERTAIN | HiddenProjectsProvider + Drift persistence fully wired. Eye icon + right-click both call toggle(). Tab filters via hiddenSet. Needs human confirmation of visual behavior. |
| SC-5 | Editing a project's STATE.md causes its card to update within one second without restarting the app | ? UNCERTAIN | Full chain verified in code: WatcherService → watcherProvider (StreamProvider keepAlive) → ref.listen in projectsProvider → ref.invalidateSelf() → rescan. Timing (< 1 second) requires live verification. |

**Score from Success Criteria:** 0/5 auto-verifiable (all require human) — see Plan-level must-haves below for automated verification.

### Plan-Level Must-Haves (Automated Verification)

**From 10-01 PLAN:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | isHidden column exists in ProjectSettingsTable and persists across app restarts | VERIFIED | `project_settings_table.dart:10-11`: `BoolColumn get isHidden => boolean().withDefault(const Constant(false))()`. `app_database.g.dart:371`: GeneratedColumn isHidden confirmed. Schema v2 migration present. |
| 2 | GsdData.version field is populated from STATE.md version regex | VERIFIED | `gsd_data.dart:14`: `final String? version`. `gsd_parser.dart:45,135-136`: `_rVersion` regex + extraction confirmed. |
| 3 | GsdData.phases list is populated from ROADMAP.md phase entries with name, status, and plan counts | VERIFIED | `gsd_parser.dart:63-241`: Full phase extraction loop. `phase_info.dart:1-16`: PhaseInfo model with all required fields. `gsd_data.dart:15`: `final List<PhaseInfo>? phases`. |
| 4 | GsdData.decisions list is populated from STATE.md Decisions section | VERIFIED | `gsd_parser.dart:52-56,139-148`: `_rDecisionSection` + `_rDecisionBullet` regex + extraction loop. `gsd_data.dart:16`: `final List<String>? decisions`. |
| 5 | QuickActionsService can open Terminal, Finder, and browser URLs | VERIFIED | `quick_actions_service.dart:1-24`: All three methods implemented with correct Process.run and launchUrl calls. |
| 6 | HiddenProjectsProvider loads hidden project IDs from Drift on build | VERIFIED | `hidden_projects_provider.dart:8-16`: build() calls `_loadFromDb()` which calls `db.getHiddenProjectIds()`. Persistence via `db.upsertProjectSettings` with `isHidden: Value(nowHidden)`. |

**From 10-02 PLAN:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | Code tab shows a card for every discovered code project with name, version, status badge, progress bar, next step, and description | VERIFIED (structural) | `code_project_card.dart:83-106`: All sections present in `_buildContent` — `_buildTitleRow` (name+version), `_buildGsdBlock` (badge+bar), nextStep (conditional), `_buildQuickActions`. Rendering needs human. |
| 8 | Cards are sorted by last git activity (most recent first) | VERIFIED | `code_tab.dart:85-94`: `sortByActivity` comparator using `git?.lastCommitDate` descending. |
| 9 | Quick action buttons visible on each card, only show when data exists | VERIFIED | `code_project_card.dart:265-277`: Terminal+Finder always shown; GitHub only if `project.git?.githubUrl != null`; Notion only if `project.gsd?.notionUrl != null`. |
| 10 | Right-click on a code card shows context menu with Ausblenden/Einblenden toggle | VERIFIED | `code_project_card.dart:300-337`: `onSecondaryTapUp` with `showMenu` + toggle_hidden item. `_showContextMenu` calls `hiddenProjectsProvider.notifier.toggle()`. |
| 11 | Hidden projects are filtered out and a banner shows the count with expand toggle | VERIFIED | `code_tab.dart:77-82,176-179`: Separation of visible/hidden; `_buildHiddenBanner` rendered when `hidden.isNotEmpty`. |
| 12 | Empty state shows friendly message with scan-dir picker when no projects found | VERIFIED | `code_tab.dart:100-108`: EmptyState shown when visible and hidden both empty. `empty_state.dart`: renders icon, heading, message, optional NSOpenPanel button. |
| 13 | Responsive grid adapts from 2 to 4 columns based on window width | VERIFIED | `code_tab.dart:113-120`: `LayoutBuilder` with switch `> 1100 => 4`, `> 750 => 3`, `_ => 2`. |

**From 10-03 PLAN:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 14 | Research tab shows cards with fuchsia accent for every research project | VERIFIED (structural) | `research_project_card.dart:65`: `colors.fuch.withValues(alpha: 0.15)` hover glow; `research_project_card.dart:114`: `Icon(Icons.science, color: colors.fuch)`. |
| 15 | Research cards show name and description but no git metrics or progress bar | VERIFIED | `research_project_card.dart:84-108`: Column contains only `_buildTitleRow`, description (conditional), `_buildQuickActions`. No GsdBlock, no progress bar. |
| 16 | Right-click on a research card shows context menu | VERIFIED | `research_project_card.dart:200-239`: `onSecondaryTapUp` → `showMenu` with toggle_hidden item. |
| 17 | Clicking a card opens a detail panel with all available GSD data | VERIFIED (structural) | `code_tab.dart:235-237`: `_showDetail` calls `showProjectDetail(context, project)`. `project_detail_panel.dart:16-38`: `showGeneralDialog` with `ProjectDetailPanel`. |
| 18 | Detail panel shows full phases list from GsdData.phases | VERIFIED | `project_detail_panel.dart:226-243`: Renders phases section iterating `gsd.phases!` with `_buildPhaseRow`. |
| 19 | Detail panel shows decisions list from GsdData.decisions | VERIFIED | `project_detail_panel.dart:246-251`: Renders `_DecisionsSection` from `gsd.decisions!`. |
| 20 | Hidden research projects are filtered with same banner pattern | VERIFIED | `research_tab.dart:75-84,161-163`: Same pattern as CodeTab. |

**Automated score: 19/20 plan-level must-haves verified (SC-1 partial due to deliberate locked-decision exclusions)**

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pro_orc/lib/data/db/tables/project_settings_table.dart` | isHidden BoolColumn with default false | VERIFIED | Line 10-11: correct column definition |
| `pro_orc/lib/data/db/app_database.dart` | Schema v2, getHiddenProjectIds helper | VERIFIED | Line 18: `schemaVersion => 2`. Line 135-139: `getHiddenProjectIds()`. |
| `pro_orc/lib/data/models/phase_info.dart` | PhaseInfo model with number, name, status, plansCompleted, plansTotal | VERIFIED | All 5 fields present with correct types |
| `pro_orc/lib/data/models/gsd_data.dart` | version, phases, decisions fields | VERIFIED | Lines 14-16: all three nullable fields |
| `pro_orc/lib/data/services/gsd_parser.dart` | Version regex, phase list extraction, decisions extraction | VERIFIED | `_rVersion` (line 45), `_rPhaseEntry` (line 63), `_rDecisionSection` (line 52), all extraction loops present |
| `pro_orc/lib/data/services/quick_actions_service.dart` | Terminal, Finder, URL open actions | VERIFIED | All three methods implemented and substantive |
| `pro_orc/lib/providers/hidden_projects_provider.dart` | HiddenProjectsNotifier with Drift persistence | VERIFIED | build(), _loadFromDb(), toggle() all wired |
| `pro_orc/lib/features/shared/status_badge.dart` | GsdStatusBadge with 4+ colored states | VERIFIED | 5 status states + fallback |
| `pro_orc/lib/features/code/code_project_card.dart` | CodeProjectCard with all data fields and quick actions | VERIFIED | Substantive implementation, all sections present |
| `pro_orc/lib/features/code/code_tab.dart` | Responsive grid, sort, hidden filter, banner | VERIFIED | LayoutBuilder, sort, hidden filter, banner all present |
| `pro_orc/lib/features/shared/empty_state.dart` | EmptyState with scan dir picker | VERIFIED | folder icon, message, optional NSOpenPanel button |
| `pro_orc/lib/features/research/research_project_card.dart` | ResearchProjectCard with fuchsia accent | VERIFIED | fuchsia glow, science icon, no git metrics |
| `pro_orc/lib/features/research/research_tab.dart` | Research grid with sort, hidden filter, banner, empty state | VERIFIED | All four features present |
| `pro_orc/lib/features/shared/project_detail_panel.dart` | Modal detail panel with all GSD data | VERIFIED | showGeneralDialog + slide+fade, phases list, decisions section, git info |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `hidden_projects_provider.dart` | `app_database.dart` | `getHiddenProjectIds()` | WIRED | Line 15: `db.getHiddenProjectIds()` called in `_loadFromDb` |
| `quick_actions_service.dart` | `url_launcher` | `launchUrl(Uri.parse(url))` | WIRED | Line 3 import + line 22: `await launchUrl(uri)` |
| `gsd_parser.dart` | `phase_info.dart` | `PhaseInfo` in GsdData.phases | WIRED | Line 4 import + line 233: `PhaseInfo(...)` construction in extraction loop |
| `code_tab.dart` | `projectsProvider` | `ref.watch(projectsProvider)` | WIRED | Line 34: `ref.watch(projectsProvider)` |
| `code_project_card.dart` | `quickActionsProvider` | `ref.read(quickActionsProvider)` | WIRED | Line 250: `ref.read(quickActionsProvider)` |
| `code_tab.dart` | `hiddenProjectsProvider` | `ref.watch(hiddenProjectsProvider)` | WIRED | Line 35: `ref.watch(hiddenProjectsProvider)` |
| `research_tab.dart` | `projectsProvider` | `ref.watch(projectsProvider)` | WIRED | Line 32: `ref.watch(projectsProvider)` |
| `project_detail_panel.dart` | `ProjectModel` | ProjectModel parameter | WIRED | Line 44: `final ProjectModel project` constructor param used throughout |
| `code_tab.dart` | `project_detail_panel.dart` | `showProjectDetail(context, project)` | WIRED | Line 236: `showProjectDetail(context, project)` — no longer a stub |
| `research_tab.dart` | `project_detail_panel.dart` | `showProjectDetail(context, project)` | WIRED | Line 211: `showProjectDetail(context, project)` |
| `projectsProvider` | `watcherProvider` | `ref.listen(watcherProvider, ...)` + `ref.invalidateSelf()` | WIRED | `projects_provider.dart:11-16`: live update chain |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| UI-01 | 10-02, 10-04 | Card-Grid Layout mit responsive Spaltenanzahl | SATISFIED | LayoutBuilder in both CodeTab and ResearchTab with 2/3/4 column logic |
| UI-02 | 10-02, 10-04 | Code-Project-Card zeigt: Name, GSD-Status, Phase-Progress, Next Step, Git-Info, Stale-Indikator | PARTIAL | Name, status, progress, next step: SATISFIED. Git-Info: moved to detail panel. Stale-Indikator: deliberately excluded via CONTEXT locked decision ("Kein Stale-Indikator — bewusst weggelassen"). |
| UI-03 | 10-03, 10-04 | Research-Project-Card zeigt: Name, Beschreibung (ohne Git-Metriken) | SATISFIED | ResearchProjectCard shows name + description only, no git fields |
| UI-06 | 10-01, 10-02, 10-03, 10-04 | Private/Visible Toggle pro Card (In-Memory) | SATISFIED (exceeds) | Toggle implemented with Drift persistence (not just in-memory as spec stated — persists across restarts) |
| ACT-01 | 10-01, 10-02, 10-04 | Open in Terminal.app via `Process.run('open', ['-a', 'Terminal', path])` | SATISFIED | `quick_actions_service.dart:8-10`: exact implementation matches spec |
| ACT-02 | 10-01, 10-02, 10-04 | Open in Finder via `Process.run('open', [path])` | SATISFIED | `quick_actions_service.dart:12-14`: exact implementation matches spec |
| ACT-03 | 10-01, 10-02, 10-04 | Open GitHub URL im Browser via url_launcher | SATISFIED | `quick_actions_service.dart:16-23`: `launchUrl(uri)` wired. Cards show button only when githubUrl present. |
| ACT-04 | 10-01, 10-02, 10-04 | Open Notion URL im Browser via url_launcher | SATISFIED | Same `openUrl` method. Cards show Notion button only when notionUrl present. |

**Orphaned requirements check:** No requirements mapped to Phase 10 in REQUIREMENTS.md that are unaccounted for — all 8 IDs claimed across plans.

**Note on UI-02:** The REQUIREMENTS.md definition includes "Git-Info, Stale-Indikator" on the card. The phase CONTEXT.md explicitly overrides this with locked decisions: "Kein Stale-Indikator — bewusst weggelassen" and "Keine Commit-Message, stattdessen Versionsnummer". Git commit info is accessible via the detail panel. This is a deliberate product decision, not an oversight.

### Anti-Patterns Found

No anti-patterns found. Scanned all 9 modified widget/service/provider files for TODO, FIXME, placeholder, return null, empty handlers. None present.

### Human Verification Required

#### 1. Code Tab Card Rendering

**Test:** Run `flutter run -d macos`, navigate to Code tab
**Expected:** Cards visible for all discovered code projects; each card shows project name (+ version if available), colored status badge, cyan progress bar with %, "Next:" step text, description excerpt, Terminal+Finder buttons always visible, GitHub/Notion buttons only when URLs exist
**Why human:** Visual rendering and actual data population from live projects cannot be verified statically

#### 2. Responsive Grid Reflow

**Test:** While Code tab is visible, drag the window narrower and wider
**Expected:** Grid reflows: below ~750px wide = 2 columns, 750-1100px = 3 columns, above 1100px = 4 columns. No overflow or card clipping at any size.
**Why human:** LayoutBuilder behavior depends on rendered widget tree dimensions

#### 3. Quick Actions Execution

**Test:** Click Terminal button, then Finder button on a code project card. If a project has a GitHub remote, click its GitHub button.
**Expected:** Terminal.app opens at the project path; Finder reveals the folder; GitHub opens in default browser
**Why human:** Process.run and launchUrl side effects require the running app

#### 4. Hidden Toggle + Drift Persistence

**Test:** Right-click a card, select "Privat". Note the card disappears and banner shows count. Then quit (from tray menu) and relaunch the app.
**Expected:** Card is hidden immediately after context menu selection. After restart, the same card is still hidden (banner still shows).
**Why human:** Drift persistence across process restarts requires running the app twice

#### 5. Detail Panel Content

**Test:** Click a code project card with a ROADMAP.md that has `### Phase N: Name` headings, and a STATE.md with a `### Decisions` section
**Expected:** Modal slides up with fade animation. Shows status + current phase + progress bar at top. Full phases list with check/arrow/dot icons and N/M plan counts. Decisions section with bullet list (collapsed by default, expandable). Close button and barrier dismiss both work.
**Why human:** Data population from gsd.phases and gsd.decisions requires actual projects with those fields populated. Animation quality requires visual inspection.

#### 6. Live Update (STATE.md Edit)

**Test:** With the app running, open a project's `.planning/STATE.md` in a text editor and change the **Status:** line (e.g., from "Building" to "Done"). Save the file.
**Expected:** The corresponding card's status badge updates within approximately one second, without restarting the app
**Why human:** Timing of the file watcher event chain (WatcherService → watcherProvider → projectsProvider invalidation → rescan) can only be confirmed in the running process

#### 7. Research Tab

**Test:** Navigate to Research tab with at least one project typed as 'research'
**Expected:** Cards show fuchsia science icon, project name, description. No progress bar, no status badge, no git info on card face. Cards sorted alphabetically. Right-click shows Privat/Oeffentlich toggle.
**Why human:** Visual fuchsia accent, absence of git elements, and alphabetical sort require running app confirmation

#### 8. Empty State

**Test:** Temporarily change the scan directory to a folder with no projects
**Expected:** "Keine Projekte gefunden" message shown with explanatory text and "Scan-Ordner waehlen" button
**Why human:** Requires running app with a deliberately empty scan directory

### Gaps Summary

No automated gaps found. All artifacts exist, are substantive, and are wired. The single partial item (UI-02 git-info/stale on card face) is a deliberate product decision documented in CONTEXT.md — not a gap.

Phase 10 automated verification is clean. The `human_needed` status reflects that Plan 10-04 was explicitly defined as a human verification gate before the phase can be marked complete. All code-level foundations are in place.

---

_Verified: 2026-02-23T07:30:43Z_
_Verifier: Claude (gsd-verifier)_
