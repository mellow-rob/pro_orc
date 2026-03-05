# Phase 20: Folder Import - Research

**Researched:** 2026-03-05
**Domain:** Flutter macOS — folder import with scaffolding, scan-dir management, type detection
**Confidence:** HIGH

## Summary

Phase 20 adds folder import functionality to the Pro Orc dashboard. The user clicks the Add+ card, selects "Importieren" from a popup menu, picks a folder via macOS native picker, sees a preview dialog with detected type and scaffold options, confirms, and the project appears in the correct tab.

The existing codebase provides nearly all building blocks: `file_selector` with `getDirectoryPath()` is already used in three places, `createProject()` handles all scaffolding (GSD skeleton, CLAUDE.md, .gitignore, git init), `_inferType()` detects project types, and `GlassDialog` provides the dialog shell. The main engineering work is: (1) refactoring AddProjectCard's `onTap` to show a popup menu, (2) building a new ImportProjectDialog, (3) creating an `importProject()` service function that reuses scaffolding logic without creating a new directory, and (4) handling scan-dir detection/expansion with watcher restart.

**Primary recommendation:** Extract scaffolding logic from `createProject()` into a shared `scaffoldProject()` function, then build `importProject()` on top. Keep the import dialog as a separate widget from CreateProjectDialog — clean separation as decided.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Add+ Karte zeigt Popup-Menue mit zwei Optionen: "Neues Projekt" und "Ordner importieren"
- "Ordner importieren" oeffnet sofort den nativen macOS Folder Picker (getDirectoryPath)
- Eigener Import-Dialog (nicht Tab im CreateProjectDialog) — saubere Trennung
- Folder Picker Cancel: stiller Abbruch, kein Feedback, zurueck zum Dashboard
- Kompakte Vorschau: Erkannter Typ (Code/Research) mit Icon, Ordnername, Checkliste der geplanten Aktionen
- Projektname = Ordnername (kein extra Textfeld, kein Rename)
- Typ-Override per Toggle/Segmented Button: Auto-erkannter Typ vorselektiert, User kann umschalten
- Keine Post-Import Aktionen (Terminal, rem-sleep) — nur Scaffolding
- Smart Defaults: Nur fehlende Dateien als aktive Toggles. Vorhandene Dateien ausgegraut mit Haekchen "Vorhanden"
- Gleiche Scaffold-Optionen wie CreateProjectDialog: GSD Skeleton, CLAUDE.md, .gitignore (mit Template), git init
- git init Toggle: ausgegraut mit "Git vorhanden" wenn .git existiert. Sonst aktiv
- Nach Scaffolding: automatischer git commit mit neuen Dateien (nur wenn git vorhanden und Dateien hinzugefuegt)
- Ordner ausserhalb Scan-Dirs: Dialog zeigt Info-Banner mit Frage "Parent als Scan-Dir hinzufuegen?" mit Checkbox
- Scan-Dir Frage erscheint im Import-Dialog selbst, kein separater Schritt
- Ordner innerhalb bestehendem Scan-Dir: Warnung "Ordner wird bereits gescannt" als Info-Banner, Scaffold trotzdem moeglich
- Nach Scan-Dir Aenderung: `ref.invalidate(watcherProvider)` fuer sofortiges Live-Update
- Dialog schliesst nach Import, Snackbar "Projekt importiert"
- Konsistent mit CreateProjectDialog-Verhalten (kein Glow-Effekt)

### Claude's Discretion
- Import-Dialog Stil (GlassDialog Variante — passend zum n3urala1 Theme)
- Popup-Menue Design fuer Add+ Karte (PopupMenuButton oder Custom)
- Checklisten-Layout im Import-Dialog (CheckboxListTile oder Custom)
- Snackbar-Design und -Dauer
- Commit-Message Format fuer Scaffold-Dateien
- .gitignore Template-Auswahl UI (Dropdown wie bei Create oder anders)
- Fehlermeldungen bei Scaffold-Problemen

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMP-01 | User kann ueber Add+ Button einen existierenden Ordner per macOS Folder Picker auswaehlen | `file_selector` already in pubspec, `getDirectoryPath()` pattern used in code_tab, settings_tab. Add+ card needs popup menu refactor. |
| IMP-02 | Projekttyp wird automatisch via _inferType()-Logik erkannt | `_inferType()` in ProjectScanner is private — need to extract or duplicate. Uses `_codeMarkers` list + subdirectory check. |
| IMP-03 | Fehlende Dateien werden automatisch angelegt | `createProject()` scaffolding logic (GSD, CLAUDE.md, .gitignore, git init) can be extracted into shared `scaffoldProject()`. Must skip existing files. |
| IMP-04 | Ordner ausserhalb Scan-Dirs: Parent-Verzeichnis als neues Scan-Dir | `db.getScanDirs()` + `db.setScanDirs()` already exist. Pattern from settings_tab `_addScanDir()`. Must invalidate watcherProvider. |
| IMP-05 | Duplikat-Erkennung: Warnung statt Duplikat | Compare selected path against scan dirs using `path.isWithin()` or startsWith. Show info banner. |
| IMP-06 | Import-Vorschau zeigt Zustand vor Bestaetigung | New ImportProjectDialog with file existence checks (Directory/File.existsSync). |
| IMP-07 | Projekt erscheint sofort im korrektem Tab | `ref.invalidate(watcherProvider)` + `ref.invalidate(projectsProvider)`. Watcher restart critical for new scan dirs. |
</phase_requirements>

## Standard Stack

### Core (already in pubspec)
| Library | Purpose | Why Standard |
|---------|---------|--------------|
| `file_selector` | Native macOS folder picker via `getDirectoryPath()` | Already used in 3 places (code_tab, settings_tab, empty_state) |
| `path` (dart:core) | Path manipulation, `p.dirname()`, `p.basename()` | Standard Dart path library |
| `dart:io` | File/Directory existence checks, Process.run for git | Core Dart I/O |
| `flutter_riverpod` | State management, provider invalidation | Project standard |
| `drift` | DB access for scan dirs, project settings | Project standard |

### No New Dependencies Required
All functionality is achievable with existing dependencies.

## Architecture Patterns

### New Files

```
lib/
  data/services/
    project_importer_service.dart    # importProject() + scaffoldProject()
  features/shared/
    import_project_dialog.dart       # Import preview dialog
```

### Modified Files

```
lib/
  data/services/
    project_creator_service.dart     # Extract scaffolding into shared function
    project_scanner.dart             # Make _inferType() or _codeMarkers accessible
  features/shared/
    add_project_card.dart            # Add popup menu (onTap -> popup with 2 options)
  features/code/
    code_tab.dart                    # Wire popup menu result to import flow
  features/research/
    research_tab.dart                # Wire popup menu result to import flow
```

### Pattern 1: Scaffold Extraction

**What:** Extract file-creation logic from `createProject()` into a reusable `scaffoldProject()` that works on existing directories.

**Why:** `createProject()` currently creates the directory first (step 1), then scaffolds. Import needs scaffolding without directory creation, and must skip existing files.

**Approach:**
```dart
/// Scaffolds files into an existing project directory.
/// Skips files that already exist (never overwrites).
Future<ScaffoldResult> scaffoldProject({
  required String projectPath,
  required String displayName,
  bool gsdSkeleton = false,
  bool claudeMd = false,
  GitignoreTemplate gitignoreTemplate = GitignoreTemplate.none,
  bool gitInit = false,
}) async {
  final warnings = <String>[];
  final created = <String>[];

  // Each step checks existence before writing
  if (gsdSkeleton) {
    final planningDir = Directory(path.join(projectPath, '.planning'));
    if (!planningDir.existsSync()) {
      // create and write files...
      created.add('.planning/');
    }
  }
  // ... similar for CLAUDE.md, .gitignore

  if (gitInit) {
    final gitDir = Directory(path.join(projectPath, '.git'));
    if (!gitDir.existsSync()) {
      // git init + commit
    }
  }

  return ScaffoldResult(created: created, warnings: warnings);
}
```

Then refactor `createProject()` to call `scaffoldProject()` internally.

### Pattern 2: File Detection for Smart Defaults

**What:** Scan the selected folder to determine which files exist before showing the dialog.

```dart
class FolderAnalysis {
  final String path;
  final String folderName;
  final ProjectType detectedType;
  final bool hasGit;
  final bool hasPlanning;
  final bool hasClaudeMd;
  final bool hasGitignore;
  final bool isInsideScanDir;
  final String? containingScanDir;  // null if outside all scan dirs
}

Future<FolderAnalysis> analyzeFolder(String folderPath, List<String> scanDirs) async {
  // Check each file/dir existence
  // Determine if path is inside any scan dir
}
```

### Pattern 3: Scan-Dir Containment Check

**What:** Determine if selected folder is inside an existing scan dir or needs a new one.

```dart
bool isInsideScanDir(String folderPath, List<String> scanDirs) {
  for (final scanDir in scanDirs) {
    // Check if folderPath is a direct or nested child of scanDir
    if (p.isWithin(scanDir, folderPath)) return true;
  }
  return false;
}
```

**Critical detail:** The scanner uses `_listProjectPaths()` which scans direct children, then one level deeper for non-project directories. So a folder at `~/code/my-project` is found if `~/code` is a scan dir. But `~/code/group/my-project` is also found because `~/code/group` is scanned as a non-project child of `~/code`. The containment check must account for this two-level scanning behavior.

### Pattern 4: Popup Menu on AddProjectCard

**What:** Replace direct `onTap` → dialog with `onTap` → popup menu → choice.

```dart
// In AddProjectCard: change onTap to show popup
PopupMenuButton or showMenu() with:
//   "Neues Projekt" → existing CreateProjectDialog
//   "Ordner importieren" → getDirectoryPath() → ImportProjectDialog
```

**Recommended:** Use `showMenu()` with `RelativeRect` positioned at the card, rather than wrapping in `PopupMenuButton` (which changes the card widget tree). The card's onTap can compute position from the tap details and call `showMenu()`.

### Anti-Patterns to Avoid
- **Don't duplicate scaffolding logic:** Extract from `createProject()`, don't copy-paste
- **Don't make _inferType() public on ProjectScanner:** Instead, extract the type detection into a standalone top-level function or make the `_codeMarkers` list accessible
- **Don't use `path.contains()` for scan-dir checks:** Use `p.isWithin()` from the `path` package for proper path containment semantics
- **Don't forget `ref.invalidate(watcherProvider)`:** This is the critical gotcha — without it, new scan dirs are not watched, and the project won't appear in real-time

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Folder picker | Custom file browser | `getDirectoryPath()` from `file_selector` | Already proven in 3 places, native macOS dialog |
| Path containment | String.contains/startsWith | `p.isWithin()` from `path` package | Handles edge cases (trailing slashes, .. segments) |
| Scaffolding | Separate copy of file-creation code | Extract from existing `createProject()` | Single source of truth for templates |
| Git existence check | Parse `.git/config` | `Directory('.git').existsSync()` | Simple, reliable |

## Common Pitfalls

### Pitfall 1: Watcher Not Restarting After Scan-Dir Addition
**What goes wrong:** New scan dir added to DB but watcher still watches old dirs. Project never appears.
**Why it happens:** `watcherProvider` has `keepAlive()`, reads dirs only at init.
**How to avoid:** Always call `ref.invalidate(watcherProvider)` after `db.setScanDirs()`. Also invalidate `projectsProvider`.
**Warning signs:** Project doesn't appear until app restart.

### Pitfall 2: Overwriting Existing Files
**What goes wrong:** Import scaffolding overwrites user's existing CLAUDE.md or .gitignore.
**Why it happens:** `createProject()` writes files unconditionally (it assumes empty directory).
**How to avoid:** `scaffoldProject()` must check `File.existsSync()` before every write. This is different from `createProject()` behavior.
**Warning signs:** User's customized files get replaced with templates.

### Pitfall 3: Race Between Scaffold and Git Commit
**What goes wrong:** Git commit runs before all scaffold files are written, or commits when nothing was actually added.
**Why it happens:** Async file writes may not complete before git add/commit.
**How to avoid:** Await all scaffold writes, then check if any files were created, only then run git add + commit. Track created files in a list.

### Pitfall 4: Parent Path Calculation for Scan-Dir
**What goes wrong:** Adding `p.dirname(selectedPath)` when the parent is `/` or `/Users`.
**Why it happens:** User picks a top-level folder.
**How to avoid:** Validate that the parent directory is reasonable (not root, not home directory itself). Show warning for suspicious paths.

### Pitfall 5: Scanner Two-Level Depth
**What goes wrong:** "Already scanned" check returns false even though the folder would be found by scanner.
**Why it happens:** Scanner doesn't just check direct children — it also scans one level deeper for non-project directories (umbrella/monorepo pattern).
**How to avoid:** The containment check should use `p.isWithin()` — if the folder is anywhere inside a scan dir within 2 levels, it's covered.

### Pitfall 6: Popup Menu Positioning
**What goes wrong:** Menu appears at wrong position or at screen origin.
**Why it happens:** `showMenu()` needs a `RelativeRect` calculated from the widget's render box position.
**How to avoid:** Use `GestureDetector.onTapUp` to capture tap position, or use a GlobalKey on the card to get its RenderBox position.

## Code Examples

### Folder Analysis (verified pattern from existing codebase)
```dart
// Based on _inferType() pattern in project_scanner.dart
// and file existence checks in createProject()
Future<FolderAnalysis> analyzeFolder(
  String folderPath,
  List<String> scanDirs,
) async {
  final folderName = p.basename(folderPath);

  // Type detection — reuse _codeMarkers logic
  final detectedType = await inferProjectType(folderPath);

  // File existence checks
  final hasGit = Directory(p.join(folderPath, '.git')).existsSync();
  final hasPlanning = Directory(p.join(folderPath, '.planning')).existsSync();
  final hasClaudeMd = File(p.join(folderPath, 'CLAUDE.md')).existsSync();
  final hasGitignore = File(p.join(folderPath, '.gitignore')).existsSync();

  // Scan-dir containment
  String? containingScanDir;
  for (final scanDir in scanDirs) {
    if (p.isWithin(scanDir, folderPath)) {
      containingScanDir = scanDir;
      break;
    }
  }

  return FolderAnalysis(
    path: folderPath,
    folderName: folderName,
    detectedType: detectedType,
    hasGit: hasGit,
    hasPlanning: hasPlanning,
    hasClaudeMd: hasClaudeMd,
    hasGitignore: hasGitignore,
    isInsideScanDir: containingScanDir != null,
    containingScanDir: containingScanDir,
  );
}
```

### Popup Menu Pattern (Flutter standard)
```dart
// In code_tab.dart / research_tab.dart — replace direct dialog call
AddProjectCard(
  accentColor: colors.cyan,
  onTap: () => _showAddMenu(context),
);

Future<void> _showAddMenu(BuildContext context) async {
  // Use showMenu with a fixed position relative to the card
  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(/* calculated */),
    items: [
      PopupMenuItem(value: 'create', child: Text('Neues Projekt')),
      PopupMenuItem(value: 'import', child: Text('Ordner importieren')),
    ],
  );

  if (result == 'create') {
    _openCreateDialog(context, 'code');
  } else if (result == 'import') {
    final dir = await getDirectoryPath();
    if (dir != null) {
      _openImportDialog(context, dir);
    }
  }
}
```

### Scan-Dir Addition (from settings_tab pattern)
```dart
// After import, if folder is outside all scan dirs:
final parentDir = p.dirname(selectedPath);
final currentDirs = await db.getScanDirs();
if (!currentDirs.contains(parentDir)) {
  currentDirs.add(parentDir);
  await db.setScanDirs(currentDirs);
}
// CRITICAL: restart watcher
ref.invalidate(watcherProvider);
ref.invalidate(projectsProvider);
```

### Smart Default Toggle (disabled + checked for existing files)
```dart
// Pattern for showing existing vs. missing file toggles
Widget _buildSmartToggle({
  required String title,
  required bool fileExists,
  required bool enabled,
  required ValueChanged<bool>? onChanged,
  required AppColors colors,
  required Color accent,
}) {
  if (fileExists) {
    // Greyed out with checkmark — "Vorhanden"
    return Row(
      children: [
        Icon(Icons.check, color: colors.textDim, size: 16),
        SizedBox(width: 8),
        Text(title, style: TextStyle(color: colors.textDim, fontSize: 13)),
        Spacer(),
        Text('Vorhanden', style: TextStyle(color: colors.textDim, fontSize: 11)),
      ],
    );
  }
  // Active toggle for missing files — reuse _buildToggle pattern from CreateProjectDialog
  return _buildToggle(/* ... */);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single scan dir | Multi-dir via JSON array in DB | v1.4 | `getScanDirs()` returns List, `setScanDirs()` takes List |
| Direct onTap on AddProjectCard | Popup menu needed for import | Phase 20 | Card widget needs callback type change or parent handles positioning |

## Open Questions

1. **AddProjectCard tap position for popup menu**
   - What we know: `showMenu()` needs `RelativeRect`. Card uses `GestureDetector.onTap` (no position info).
   - What's unclear: Best approach — change to `onTapUp` for position, use `GlobalKey` + `findRenderObject`, or use `PopupMenuButton` wrapper.
   - Recommendation: Use `onTapUp` with `TapUpDetails.globalPosition` to calculate `RelativeRect`. Simplest change to AddProjectCard.

2. **Extracting _inferType() from ProjectScanner**
   - What we know: `_inferType()` and `_codeMarkers` are private in `ProjectScanner`. Import dialog needs type detection before scanning.
   - What's unclear: Whether to make it a public static method, a top-level function, or duplicate the logic.
   - Recommendation: Extract to a top-level `inferProjectType()` function in a separate file or in `project_scanner.dart`. The scanner can then call it too.

3. **Auto-commit after scaffold**
   - What we know: Decision says "automatischer git commit mit neuen Dateien (nur wenn git vorhanden und Dateien hinzugefuegt)".
   - What's unclear: Should it use `git add -A` (catches everything) or `git add` specific files?
   - Recommendation: Use `git add -A` + commit only if the scaffolding actually created files. Track created files, skip commit if list is empty. Commit message: "scaffold: GSD skeleton, CLAUDE.md" (listing what was added).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `package:test` (Dart) |
| Config file | None (standard `flutter test`) |
| Quick run command | `cd pro_orc && flutter test test/data/` |
| Full suite command | `cd pro_orc && flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMP-01 | Folder picker integration | manual-only | N/A — requires macOS UI | N/A |
| IMP-02 | Type detection on existing folder | unit | `flutter test test/data/project_importer_test.dart -x` | Wave 0 |
| IMP-03 | Scaffold skips existing files | unit | `flutter test test/data/project_importer_test.dart -x` | Wave 0 |
| IMP-04 | Scan-dir expansion | unit | `flutter test test/data/project_importer_test.dart -x` | Wave 0 |
| IMP-05 | Duplicate detection | unit | `flutter test test/data/project_importer_test.dart -x` | Wave 0 |
| IMP-06 | Import preview dialog | manual-only | N/A — widget test would need extensive mocking | N/A |
| IMP-07 | Live update after import | manual-only | N/A — requires full provider + watcher setup | N/A |

### Sampling Rate
- **Per task commit:** `cd pro_orc && flutter test test/data/`
- **Per wave merge:** `cd pro_orc && flutter test`
- **Phase gate:** Full suite green + `flutter analyze` clean

### Wave 0 Gaps
- [ ] `test/data/project_importer_test.dart` — covers IMP-02, IMP-03, IMP-04, IMP-05
- [ ] Extract `inferProjectType()` to be testable outside `ProjectScanner`

## Sources

### Primary (HIGH confidence)
- Existing codebase: `project_creator_service.dart` — scaffold patterns, git init logic
- Existing codebase: `project_scanner.dart` — `_inferType()`, `_codeMarkers`, scanner depth behavior
- Existing codebase: `code_tab.dart`, `research_tab.dart` — AddProjectCard wiring, post-creation flow
- Existing codebase: `settings_tab.dart` — scan-dir add/remove/save pattern
- Existing codebase: `watcher_provider.dart` — keepAlive + scanDir read behavior
- Existing codebase: `app_database.dart` — `getScanDirs()`, `setScanDirs()` API

### Secondary (MEDIUM confidence)
- Flutter `showMenu()` API — standard popup menu positioning
- `path` package `isWithin()` — path containment check

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, no new deps
- Architecture: HIGH — clear extraction pattern from existing code, straightforward new files
- Pitfalls: HIGH — watcher restart gotcha well-documented in MEMORY.md, file overwrite risk obvious from code review

**Research date:** 2026-03-05
**Valid until:** 2026-04-05 (stable — no external dependencies changing)
