# Phase 10: Card Widgets + Quick Actions - Research

**Researched:** 2026-02-20
**Domain:** Flutter card grid UI, Riverpod state, Drift DB schema migration, Process.run / url_launcher quick actions
**Confidence:** HIGH

## Summary

Phase 10 replaces the two placeholder tabs (Code, Research) with fully live project card grids. The data layer, Riverpod providers, file watcher, and models are all complete from Phases 7-8. The visual foundation (GlassCard, AppColors, OrbBackground, NavigationRail) is complete from Phase 9. This phase is primarily a UI construction task: build card widgets, wire providers, implement actions, and persist the hidden-project toggle to Drift.

The codebase already has everything needed. `projectsProvider` delivers `List<ProjectModel>` and auto-refreshes on file changes. `GsdData`, `GitData`, and `ProjectModel` already carry all required fields. The `ProjectSettingsTable` exists in Drift and needs only one new column (`isHidden`) added via a schema migration to support persistent hide/show. Quick actions use `Process.run` (for Terminal/Finder, already the established pattern from `git_reader.dart`) and `url_launcher` (for GitHub/Notion URLs, not yet in pubspec).

**Primary recommendation:** Build the three UI zones in this order — (1) CodeProjectCard + ResearchProjectCard widgets, (2) responsive grid with LayoutBuilder in CodeTab/ResearchTab, (3) hidden-project toggle with Drift migration, (4) detail panel via showGeneralDialog, (5) add url_launcher for browser actions. Each zone is independently testable.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Karten-Layout & Grid
- Responsive Grid, passt sich der Fensterbreite an (2-4 Spalten)
- Großzügige Dichte: alle Felder mit Abstand dargestellt, Next-Step-Text mehrzeilig sichtbar
- Sortierung nach letzter Aktivität (zuletzt geändertes Projekt zuerst)
- Kein Stale-Indikator — bewusst weggelassen
- Kein Drag & Drop — Sortierung ist automatisch

#### Code-Karten vs. Research-Karten
- Visuell unterschiedlich: andere Akzentfarbe + andere Icons
- Research-Karten nutzen Fuchsia-Akzent (statt Cyan), eigenes Research-Icon
- Code-Karten nutzen Cyan-Akzent, eigenes Code-Icon
- Gleiche GlassCard-Basis, aber Farb-/Icon-Differenzierung macht Typ sofort erkennbar

#### Karten-Inhalte (Code-Tab)
- Projektname + Versionsnummer in der Titelzeile (z.B. "Pro Orc v1.1")
- Farbiger Badge-Chip für GSD-Status
- 4 Status-Zustände: In Progress (Cyan), Planned (Gelb/Orange), Complete (Grün), Not Started (Grau)
- Horizontale Progress-Bar in Cyan mit Prozent-Anzeige
- Next Step prominent dargestellt (eigener Bereich, gut lesbar)
- Projekt-Beschreibung aus PROJECT.md gekürzt (1-2 Zeilen, Ellipsis)
- Keine Commit-Message, stattdessen Versionsnummer neben dem Projektnamen

#### Karten-Inhalte (Research-Tab)
- Projektname + Beschreibung (gekürzt)
- Keine Git-Metriken
- Fuchsia-Akzent, Research-Icon

#### Empty-State
- Freundlicher Hinweis-Text wenn keine Projekte gefunden werden
- Anleitung/Erklärung wie man Projekte anlegt
- macOS nativer Ordner-Picker (NSOpenPanel) zum Ändern des Scan-Ordners
- Scan-Pfad wird in Drift-DB als scanDir gespeichert

#### Quick-Action-Buttons
- Vier Actions: Terminal (System-Standard), Finder, GitHub, Notion
- Immer sichtbar auf der Karte (nicht nur bei Hover)
- Nur vorhandene Links anzeigen (kein GitHub-Button wenn kein Remote)
- Darstellungsart und Position: Claude's Discretion (passend zum Karten-Design und Platz)
- Erweiterbar designen — später kommen weitere Actions hinzu
- System-Standard-Terminal öffnen (nicht hardcoded Terminal.app)

#### Karten-Interaktionen
- Klick auf Karte öffnet Detail-Ansicht mit allen GSD-Daten (volle Beschreibung, alle Phasen, Roadmap-Übersicht, Decisions)
- Detail-Ansicht Typ (expandiert/Panel/Modal): Claude's Discretion
- Private/Visible Toggle: Auge-Icon auf der Karte + Rechtsklick-Kontextmenü
- Persistent in Drift-DB gespeichert (überlebt App-Neustarts)
- Hinweis-Banner am Ende des Grids: "X Projekte ausgeblendet — Alle zeigen"
- Banner-Klick klappt ausgeblendete Projekte auf

### Claude's Discretion
- Hover-Effekt auf Karten (Glow, Anheben, oder beides)
- Quick-Action-Button Darstellung (Icons only vs. Icons+Tooltip vs. Icons+Labels)
- Quick-Action-Button Position auf der Karte
- Quick-Action-Button Feedback (Hover-Highlight, Click-Animation)
- Detail-Ansicht Typ und Animation
- Update-Animationen bei Live-Datenänderung (Flash, smooth Transition, oder keine)

### Deferred Ideas (OUT OF SCOPE)
- Claude Code Quick-Action-Button — spätere Phase
- VS Code/Cursor Quick-Action-Button — spätere Phase
- Stale-Indikator — bewusst nicht gewünscht
- Drag & Drop Sortierung — nicht gewünscht
- Konfigurierbares Terminal (iTerm, Warp) — System-Standard reicht vorerst
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-01 | Card-Grid Layout mit responsive Spaltenanzahl | LayoutBuilder + GridView.builder with crossAxisCount derived from constraints.maxWidth — verified pattern |
| UI-02 | Code-Project-Card zeigt: Name, GSD-Status, Phase-Progress, Next Step, Git-Info, Stale-Indikator | All fields exist in ProjectModel/GsdData/GitData; note: Stale-Indikator deferred per CONTEXT.md |
| UI-03 | Research-Project-Card zeigt: Name, Beschreibung (ohne Git-Metriken) | Subset of UI-02 fields; same data model, different card widget |
| UI-06 | Private/Visible Toggle pro Card (persistent in Drift-DB per CONTEXT.md) | Drift migration pattern verified: add `isHidden` BoolColumn with withDefault(Constant(false)), increment schemaVersion to 2, use m.addColumn() in onUpgrade |
| ACT-01 | Open in Terminal (System-Standard) | Process.run('open', [path]) without -a flag opens in system-default terminal; same runInShell:true pattern from git_reader.dart |
| ACT-02 | Open in Finder | Process.run('open', [path]) opens folder in Finder (already implemented in v1.0: execAsync("open 'path'")) |
| ACT-03 | Open GitHub URL im Browser | url_launcher 6.3.2: launchUrl(Uri.parse(githubUrl)) — add to pubspec |
| ACT-04 | Open Notion URL im Browser | url_launcher 6.3.2: same launchUrl pattern as ACT-03 |
</phase_requirements>

---

## Standard Stack

### Core (already in pubspec)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^3.2.1 | State management | Already in use; projectsProvider delivers List<ProjectModel> |
| drift | ^2.31.0 | SQLite persistence | Already in use; ProjectSettingsTable exists |
| drift_flutter | ^0.2.8 | Drift native backend | Already in use |

### To Add
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| url_launcher | ^6.3.2 | Open GitHub/Notion URLs in browser | Official Flutter team package; macOS desktop supported; current version 6.3.2 as of Feb 2026 |

### Already Available (no addition needed)
| Library | Purpose | Notes |
|---------|---------|-------|
| dart:io Process.run | Terminal + Finder actions | Pattern established in git_reader.dart; sandbox disabled in entitlements |
| GlassCard widget | Card base | Built in Phase 9 at lib/features/shell/glass_card.dart |
| AppColors ThemeExtension | Design tokens | 16 pre-computed sRGB tokens in lib/theme/n3_colors.dart |
| projectsProvider | Live data | FutureProvider<List<ProjectModel>>, auto-invalidates on file change |

**Installation:**
```bash
# From pro_orc/ directory
flutter pub add url_launcher
```

No macOS entitlement changes needed — sandbox is already disabled in both DebugProfile.entitlements and Release.entitlements. No Info.plist LSApplicationQueriesSchemes needed for https:// URLs (only needed when using canLaunchUrl for custom schemes).

---

## Architecture Patterns

### Recommended File Structure
```
lib/
  features/
    code/
      code_tab.dart              # Replace placeholder — ConsumerWidget, GridView
      code_project_card.dart     # New — CodeProjectCard widget
    research/
      research_tab.dart          # Replace placeholder — ConsumerWidget, GridView
      research_project_card.dart # New — ResearchProjectCard widget
    shared/
      status_badge.dart          # New — GsdStatusBadge chip (shared by both cards)
      project_detail_panel.dart  # New — detail view opened on card tap
      empty_state.dart           # New — empty state widget with scan dir picker
  providers/
    hidden_projects_provider.dart # New — Riverpod provider for hide/show state
  data/
    db/
      tables/
        project_settings_table.dart  # Modify — add isHidden BoolColumn
      app_database.dart              # Modify — increment schemaVersion, add migration
      app_database.g.dart            # Regenerate — run build_runner
    services/
      quick_actions_service.dart     # New — Process.run + url_launcher wrapper
```

### Pattern 1: Responsive Grid with LayoutBuilder
**What:** Wrap GridView.builder in LayoutBuilder to compute crossAxisCount from available width
**When to use:** Any grid that must adapt from 2 to 4 columns based on window width

```dart
// Source: Flutter docs + verified community pattern
LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth;
    final columns = width > 1200 ? 4 : width > 800 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85, // tall enough for generous density
      ),
      itemCount: projects.length,
      itemBuilder: (context, i) => CodeProjectCard(project: projects[i]),
    );
  },
)
```

**Note on childAspectRatio:** Cards with multiline Next Step text need a ratio ≤ 1.0. Use `mainAxisExtent` on `SliverGridDelegateWithFixedCrossAxisCount` (Flutter 3.x) to set a fixed height per card instead of a ratio — this avoids overflow when content varies.

### Pattern 2: Sorting by Last Activity
**What:** Sort `List<ProjectModel>` by most recent activity before rendering
**Data source:** `git?.lastCommitDate` if available, otherwise fall back to `ProjectModel.isStale` timestamp (not directly available) — use git date when present

```dart
// Sort descending: most recently active first
projects.sort((a, b) {
  final aDate = a.git?.lastCommitDate;
  final bDate = b.git?.lastCommitDate;
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;   // no git = older
  if (bDate == null) return -1;
  return bDate.compareTo(aDate); // descending
});
```

**Caveat:** Current `projectsProvider` sorts by displayName (alphabetical) in `ProjectScanner.scanAll()`. The sort for Phase 10 should happen at the tab level (in CodeTab/ResearchTab), not in the scanner, to avoid breaking the scanner contract.

### Pattern 3: Hidden Projects Provider (Riverpod + Drift)
**What:** `NotifierProvider<HiddenProjectsNotifier, Set<String>>` — tracks which folderId strings are hidden; reads initial state from Drift on build, persists on toggle.

```dart
// lib/providers/hidden_projects_provider.dart
class HiddenProjectsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // Kick off async load — returns empty set synchronously, updates on load
    _loadFromDb();
    return {};
  }

  Future<void> _loadFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final hidden = await db.getHiddenProjectIds();
    state = hidden;
  }

  Future<void> toggle(String folderId) async {
    final db = ref.read(appDatabaseProvider);
    final nowHidden = !state.contains(folderId);
    await db.upsertProjectSettings(
      ProjectSettingsTableCompanion(
        folderId: Value(folderId),
        isHidden: Value(nowHidden),
      ),
    );
    state = nowHidden
        ? {...state, folderId}
        : state.where((id) => id != folderId).toSet();
  }
}

final hiddenProjectsProvider =
    NotifierProvider<HiddenProjectsNotifier, Set<String>>(
  HiddenProjectsNotifier.new,
);
```

**Alternative:** Use `StateProvider<Set<String>>` for simplicity if async init is handled elsewhere. The `NotifierProvider` approach is cleaner for Riverpod 3.x.

### Pattern 4: Drift Schema Migration (add isHidden column)
**What:** Add `BoolColumn get isHidden` to ProjectSettingsTable, bump schemaVersion to 2, implement onUpgrade.

```dart
// In project_settings_table.dart — add:
BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

// In app_database.dart — change:
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(projectSettingsTable, projectSettingsTable.isHidden);
    }
  },
);
```

After changing the table definition, regenerate generated code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated `app_database.g.dart` must be committed (existing convention — it is not gitignored).

### Pattern 5: Quick Actions Service
**What:** Pure Dart service wrapping Process.run and url_launcher, no Flutter imports.

```dart
// lib/data/services/quick_actions_service.dart
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class QuickActionsService {
  /// Opens project folder in system-default terminal.
  /// Uses 'open <path>' which macOS routes to the user's default terminal app.
  Future<void> openInTerminal(String projectPath) async {
    await Process.run('open', [projectPath], runInShell: true);
  }

  /// Reveals project folder in Finder.
  Future<void> openInFinder(String projectPath) async {
    await Process.run('open', [projectPath], runInShell: true);
  }

  /// Opens URL in system default browser.
  Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // Silently fail — consistent with services returning empty/null on error
    }
  }
}
```

**Terminal vs Finder:** Both use `open <path>`. The macOS `open` command without `-a` uses the system default application for the file type. For directories, macOS opens Finder by default. To open a terminal at a path, the correct approach is `open -a Terminal <path>` for Terminal.app, but the CONTEXT.md decision is "System-Standard-Terminal" — meaning whatever the user has set as default. This is achieved via `open <path>` which, for a directory, will open in Finder. To open a terminal at the path, the correct system-default approach on macOS is `open -a $(defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers | ...)` which is complex. The practical solution is `open -a Terminal <path>` (opens Terminal.app, which is the system app) but the v1.0 reference also uses `open -a Terminal`. Since the CONTEXT.md deferred "konfigurierbares Terminal" and says "System-Standard reicht" — the safe implementation uses `open -a Terminal <path>` as the default, which is effectively the macOS system standard for most users.

**Open Question on Terminal Action:** See Open Questions section.

### Pattern 6: Status Badge Widget
**What:** Stateless widget mapping GsdData.status strings to colored Container + Text.

Status → Color mapping (using AppColors design tokens):
| Status string | Color | AppColors token |
|--------------|-------|----------------|
| `building` | Cyan | `colors.cyan` |
| `planning` | Yellow/Orange | `Color(0xFFE0A020)` (no token — use inline) |
| `done` | Green | `Color(0xFF22C55E)` (no token — use inline) |
| `research` | Fuchsia | `colors.fuch` |
| `paused` | Amber | `Color(0xFFF59E0B)` (no token — use inline) |
| `archived` | Dim | `colors.textDim` |
| null | Gray | `colors.textDis` |

The CONTEXT.md specifies 4 states: "In Progress (Cyan), Planned (Gelb/Orange), Complete (Grün), Not Started (Grau)". These map to GsdParser status values: `building` → In Progress, `planning` → Planned, `done` → Complete, `null/archived` → Not Started.

### Pattern 7: Version Number Extraction
**What:** Extract version string like "v1.1" from `gsd.currentPhase` or `gsd.description`.

The CONTEXT.md decision: "Versionsnummer aus GSD Milestone-Info extrahieren (z.B. 'v1.1')". Looking at the actual STATE.md for this project: `**Current focus:** Phase 9 — Theme + UI Shell (v1.1)`. The version appears in `currentPhase` which GsdParser reads as: `Phase: 9 of 11 (Theme + UI Shell)` — the version is NOT in currentPhase as parsed.

The version appears in the raw STATE.md text but not in any currently-parsed GsdData field. Options:
1. Add a `version` regex to `GsdParser` (e.g., match `v\d+\.\d+` from the currentPhase line or a dedicated Version: field)
2. Parse version from `gsd.currentPhase` string in the UI (fragile)
3. Show project milestone from ROADMAP.md (already parsed as `plansCompleted/plansTotal`)

**Recommended approach:** Add a `version` field to `GsdData` and a corresponding regex in `gsd_parser.dart` that matches `v\d+\.\d+[\.\d]*` from the STATE.md content. If no version found, show only the project name. This is a small, targeted parser addition.

### Pattern 8: Detail Panel (showGeneralDialog with slide animation)
**What:** Full-screen detail panel with all GSD data, opened on card tap.

```dart
// Recommended: showGeneralDialog with slide-up animation
await showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 300),
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(opacity: animation, child: child),
    );
  },
  pageBuilder: (context, animation, secondaryAnimation) =>
      ProjectDetailPanel(project: project),
);
```

The `ProjectDetailPanel` should be a `GlassCard`-styled full-screen (or large Dialog) showing: full description, all phases with status, roadmap overview, decisions. Content comes from raw file reads or the already-parsed `GsdData` fields.

**Note:** `GsdData` does not currently store raw phase list or decisions — it only stores `currentPhase` string, `phasesCompleted`, `phasesTotal`. For Phase 10, the detail panel can show what's available. Full raw content display (all phases list, decisions) would require parser additions — this is an open question for the planner to scope.

### Pattern 9: Hidden Projects Banner
**What:** Banner at bottom of grid when projects are hidden, with tap to expand.

```dart
// Mimics v1.0 <details>/<summary> expand behavior
if (hiddenCount > 0)
  _HiddenProjectsBanner(
    count: hiddenCount,
    isExpanded: _showHidden,
    onTap: () => setState(() => _showHidden = !_showHidden),
  )
```

The banner uses local `StatefulWidget` state (`_showHidden`) in the tab widget, not Riverpod — it's a pure UI toggle that resets on tab switch (intentional, matches v1.0 behavior).

### Anti-Patterns to Avoid
- **Sorting in ProjectScanner.scanAll():** The scanner sorts alphabetically; override sort at the tab level, not the scanner level. Changing the scanner breaks the existing test suite.
- **Using `withOpacity()`:** The codebase uses `withValues(alpha:)` exclusively (convention from CLAUDE.md). Every alpha operation must use this form.
- **Relative imports:** CLAUDE.md mandates package imports only (`package:pro_orc/...`).
- **Rebuilding card widgets on every watcher tick:** The `projectsProvider` already debounces via WatcherService. Cards rebuild only when the provider resolves — no additional debouncing needed in the UI.
- **Calling `url_launcher` for local paths:** Use `Process.run('open', [...])` for file system paths; `launchUrl` only for http/https URLs.
- **AnimatedSwitcher without keys:** If using AnimatedSwitcher for live-update flash, add a `ValueKey` to the card widget; otherwise Flutter won't detect the child changed and won't animate.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Responsive column count | Custom breakpoint manager | `LayoutBuilder` + inline math | Flutter built-in, zero deps |
| Open URL in browser | `Process.run('open', [url])` | `url_launcher` `launchUrl()` | Handles macOS correctly; Process.run for URLs is fragile |
| Persist hidden projects | Custom file-based store | Drift `ProjectSettingsTable.isHidden` | Already have Drift, schema migration is trivial |
| Status color mapping | Color computation logic | Static `const Map<String, Color>` | Stateless, testable, avoids runtime errors |
| Detail view navigation | Push/pop route | `showGeneralDialog` | Modal pattern fits dashboard; no routing needed; dismissable with click-outside |

**Key insight:** Everything "custom" in this phase is widget composition, not new infrastructure. The entire data layer (Phase 7), reactive state (Phase 8), and visual base (Phase 9) are complete. Phase 10 is UI assembly.

---

## Common Pitfalls

### Pitfall 1: childAspectRatio overflow
**What goes wrong:** Cards with variable-length Next Step text overflow the fixed aspect-ratio cell in GridView.
**Why it happens:** `SliverGridDelegateWithFixedCrossAxisCount.childAspectRatio` enforces exact height; text wrapping adds height.
**How to avoid:** Use `mainAxisExtent` (fixed pixel height per card, e.g. 280px) instead of `childAspectRatio`. Alternatively, use `SliverGridDelegateWithMaxCrossAxisExtent` for a max-width approach.
**Warning signs:** Red overflow indicators in debug mode on cards with long Next Step text.

### Pitfall 2: Drift migration not run on first install
**What goes wrong:** New column added but `schemaVersion` not incremented — existing DB rows missing the column, causing runtime errors.
**Why it happens:** Developer tests with fresh install, forgets existing installations have schemaVersion=1.
**How to avoid:** Always increment `schemaVersion` AND implement `onUpgrade`. Test by manually deleting the app's SQLite file and running again.
**Warning signs:** `SqliteException: table has no column named is_hidden` at runtime.

### Pitfall 3: build_runner not re-run after Drift table changes
**What goes wrong:** `app_database.g.dart` out of sync with table definition; compile errors or missing Companion fields.
**Why it happens:** Developer adds column to table but forgets to regenerate.
**How to avoid:** Always run `dart run build_runner build --delete-conflicting-outputs` after any Drift table change. Commit the updated `.g.dart` file.
**Warning signs:** `ProjectSettingsTableCompanion` missing `isHidden` field.

### Pitfall 4: Terminal action opens Finder instead of terminal
**What goes wrong:** `Process.run('open', [path])` on a directory opens Finder, not a terminal.
**Why it happens:** macOS `open <directory>` default handler is Finder, not Terminal.
**How to avoid:** Use `Process.run('open', ['-a', 'Terminal', path])` for the Terminal action and `Process.run('open', [path])` for the Finder action. This is distinct from using a configurable terminal (which is deferred).
**Warning signs:** Clicking Terminal button opens Finder window instead.

### Pitfall 5: hiddenProjectsProvider async init race
**What goes wrong:** Grid renders with all projects visible, then flickers when hidden set loads from Drift.
**Why it happens:** `NotifierProvider.build()` returns empty Set synchronously, then updates after DB read.
**How to avoid:** Use `AsyncNotifierProvider` instead of `NotifierProvider` if flicker is unacceptable — then the tab shows a loading state while the hidden set loads. Alternatively, use `FutureProvider` for the initial load and hold state in memory only after first read. For this app (fast local DB), the flicker is likely sub-50ms and acceptable.
**Warning signs:** Brief flicker of all cards before hidden ones disappear on app launch.

### Pitfall 6: Sorting breaks on projects with no git data
**What goes wrong:** `NullPointerException` or `Comparable` error when sorting by `lastCommitDate` and some projects have `null` git data.
**Why it happens:** Sort comparator assumes non-null.
**How to avoid:** Null-safe comparator (see Pattern 2 above) — always handle null dates explicitly.
**Warning signs:** Crash in debug mode on sort when non-git-repo projects are present.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Responsive GridView
```dart
// Source: Flutter cookbook (docs.flutter.dev/cookbook/lists/grid-lists)
LayoutBuilder(
  builder: (context, constraints) {
    final columns = switch (constraints.maxWidth) {
      > 1100 => 4,
      > 750 => 3,
      _ => 2,
    };
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 280, // fixed height avoids overflow
      ),
      itemCount: projects.length,
      itemBuilder: (_, i) => CodeProjectCard(project: projects[i]),
    );
  },
)
```

### Open URL with url_launcher
```dart
// Source: pub.dev/packages/url_launcher (version 6.3.2)
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri)) {
    // Log or silently ignore — consistent with service error handling
  }
}
```

### Open Terminal (Terminal.app at path)
```dart
// Source: v1.0 reference + macOS open man page
// Pattern consistent with git_reader.dart Process.run usage
Future<void> openInTerminal(String path) async {
  await Process.run('open', ['-a', 'Terminal', path], runInShell: true);
}
```

### Open Finder at path
```dart
// Source: v1.0 reference (app/actions.ts: execAsync("open 'path'"))
Future<void> openInFinder(String path) async {
  await Process.run('open', [path], runInShell: true);
}
```

### Drift column addition + migration
```dart
// Source: drift.simonbinder.eu/migrations/api/

// In project_settings_table.dart:
BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

// In app_database.dart:
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(projectSettingsTable, projectSettingsTable.isHidden);
    }
  },
);
```

### Consume projectsProvider in a tab
```dart
// Source: existing codebase pattern (shell_screen.dart uses ref.watch)
class CodeTab extends ConsumerWidget {
  const CodeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(error: e),
      data: (projects) {
        final codeProjects = projects
            .where((p) => p.projectType == 'code' || p.projectType == null)
            .toList()
          ..sort((a, b) => /* last activity sort */);
        return _CodeGrid(projects: codeProjects);
      },
    );
  }
}
```

### GSD Status Badge
```dart
// Source: v1.0 statusBadge.tsx (ported to Flutter)
Widget _statusBadge(String? status, AppColors colors) {
  final (label, color) = switch (status) {
    'building' => ('In Progress', colors.cyan),
    'planning' => ('Planned', const Color(0xFFE0A020)),
    'done' => ('Complete', const Color(0xFF22C55E)),
    'research' => ('Research', colors.fuch),
    'paused' => ('Paused', const Color(0xFFF59E0B)),
    _ => ('Not Started', colors.textDis),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `withOpacity()` | `withValues(alpha:)` | Avoids deprecation warning — CLAUDE.md mandates this |
| Relative imports | Package imports only | CLAUDE.md convention — no relative imports |
| Sort in scanner | Sort in tab widget | Scanner sorts alpha; tab re-sorts by activity |
| `StateProvider` for simple state | `NotifierProvider` | Riverpod 3.x recommendation; StateProvider still works but less idiomatic |

**Deprecated/outdated:**
- `withOpacity()`: Deprecated in Flutter 3.x — use `withValues(alpha:)` as per CLAUDE.md
- `GridView.count()`: Works but `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount` is more flexible for dynamic content

---

## Open Questions

1. **Terminal action: `open -a Terminal` vs system default**
   - What we know: CONTEXT.md says "System-Standard-Terminal öffnen" and defers "konfigurierbares Terminal"
   - What's unclear: macOS has no single "open a directory in default terminal" shell command without reading LSHandlers
   - Recommendation: Use `open -a Terminal <path>` as the Phase 10 implementation. This opens Terminal.app, which is the macOS system terminal and the practical default for virtually all users. The deferred "konfigurierbares Terminal" feature (iTerm, Warp) would be a Phase 12+ addition. The v1.0 reference uses this exact approach.

2. **Detail panel content: raw files vs parsed GsdData**
   - What we know: CONTEXT.md says "volle Beschreibung, alle Phasen, Roadmap-Übersicht, Decisions". `GsdData` only has `currentPhase` string, not a list of all phases.
   - What's unclear: Whether the planner should add a raw-file reader for the detail panel, or extend `GsdData` with more fields, or scope the detail panel to what's already parsed.
   - Recommendation: Scope the detail panel in Phase 10 to what `GsdData` already provides (status, currentPhase, nextStep, phaseProgress, plansCompleted/Total, description, notionUrl). Add a "View in Finder" link to open the `.planning/` folder. Full raw-content display is a Phase 12+ enhancement.

3. **Version number: parser extension or UI extraction**
   - What we know: CONTEXT.md says "Versionsnummer aus GSD Milestone-Info extrahieren". The current `GsdData` has no version field. The version appears in STATE.md raw content (e.g., "v1.1") but is not parsed.
   - What's unclear: How much parser work is in scope for Phase 10.
   - Recommendation: Add a simple `version` field to `GsdData` and a single regex to `gsd_parser.dart` matching `v\d+\.\d+` from STATE.md content. This is a one-line addition to the parser and one field in the model. Show version only if found; omit if not.

4. **Empty state scan dir picker: file_selector or manual path entry**
   - What we know: CONTEXT.md requires "macOS nativer Ordner-Picker (NSOpenPanel)".
   - What's unclear: Whether `file_selector` package (official Flutter team) should be added to pubspec.
   - Recommendation: Add `file_selector` package for the NSOpenPanel. It's the official Flutter team package for this. Limit scope to the empty state only — the picker fires only when no projects are found or scan dir is unconfigured.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase — `pro_orc/lib/` — all models, providers, services, theme verified by direct read
- `drift.simonbinder.eu/migrations/api/` — addColumn migration pattern verified
- `pub.dev/packages/url_launcher` — version 6.3.2, macOS support, launchUrl API verified

### Secondary (MEDIUM confidence)
- Flutter cookbook `docs.flutter.dev/cookbook/lists/grid-lists` — GridView.builder pattern
- `riverpod.dev/docs/concepts2/` — NotifierProvider and family patterns
- v1.0 reference `pro-orc/components/codeProjectCard.tsx`, `researchProjectCard.tsx`, `projectTabs.tsx` — UX reference for card layout, status colors, hidden-project banner

### Tertiary (LOW confidence)
- macOS `open` command behavior for "default terminal" — from scriptingosx.com + ss64.com; practical behavior verified via v1.0 implementation using `open -a Terminal`

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified via pub.dev and existing codebase
- Architecture: HIGH — patterns derived from existing codebase conventions + official docs
- Pitfalls: HIGH — most from direct codebase inspection; Drift migration from official docs
- Open Questions: MEDIUM — recommendations are reasonable but require planner decision

**Research date:** 2026-02-20
**Valid until:** 2026-03-22 (stable libraries; 30-day window)
