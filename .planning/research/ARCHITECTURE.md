# Architecture Patterns

**Domain:** v1.5 Feature Integration (Folder Import, Detail-Panel, Memory Tab)
**Researched:** 2026-03-05
**Confidence:** HIGH -- based on direct codebase analysis of all integration points

## Executive Summary

All three v1.5 features integrate cleanly into the existing three-layer architecture without requiring structural changes. The codebase already has the primitives needed: `file_selector` for folder picking, `MemoryData` for memory reading, and `_SectionCard` for detail-panel layout. The work is additive -- new files, minor modifications to existing ones, zero refactors.

## Current System Overview

```
ShellScreen (_SideNav + IndexedStack)
  index 0: CodeTab        -- grid of CodeProjectCards
  index 1: ResearchTab    -- grid of ResearchProjectCards
  index 2: ClaudeToolsTab -- skills/MCP/plugins inventory
  index 3: AgentsTab      -- agent cards
  index 4: SettingsTab    -- scan dirs, ignore patterns, git path, autostart

projectsProvider (FutureProvider<List<ProjectModel>>)
  -> ref.listen(watcherProvider) -> invalidateSelf on FS events
  -> projectScannerProvider.scanAll()
    -> GsdParser, GitReader, readMemoryData
    -> _inferType, _extractUsedAgents, _scanMdFiles

watcherProvider (StreamProvider, keepAlive)
  -> WatcherService.multi([...scanDirs, ~/.claude/projects/])

AppDatabase (Drift SQLite v2)
  -> getScanDirs(), getConfig(), getProjectSettings()
  -> setScanDirs(), upsertProjectSettings()
```

## v1.5 Integration Map

```
FEATURE 1: Folder Import
  Touch: CodeTab, ResearchTab (new _openImportDialog method)
         new ImportProjectDialog widget
         new importProject() service function
         AppDatabase.getScanDirs/setScanDirs (existing, no changes)
         projectsProvider (invalidate after import -- existing pattern)

FEATURE 2: Detail-Panel Text Improvements
  Touch: ProjectDetailPanel._buildBody (existing widget, modify in place)
         _SectionCard (existing, minor style tweaks)
         No new files, no new providers, no new services

FEATURE 3: Memory Tab
  Touch: ShellScreen._SideNav._items (add entry at index 4)
         ShellScreen IndexedStack (add MemoryTab at index 4, Settings -> 5)
         new MemoryTab widget
         new memoryFilesProvider (FutureProvider)
         new memory_files_scanner.dart service
         existing memory_reader.dart (reuse readMemoryData/encodeProjectPath)
         existing watcherProvider (already watches ~/.claude/projects/)
```

## Component Boundaries

### Feature 1: Folder Import

| Component | Layer | Status | Responsibility |
|-----------|-------|--------|----------------|
| `ImportProjectDialog` | Presentation | NEW | Folder picker UI, scaffold toggle options, scan-dir expansion logic |
| `importProject()` | Service | NEW | Validate folder, optionally scaffold .planning/, persist projectType |
| `CodeTab._openImportDialog()` | Presentation | MODIFY | Wire up import dialog, same pattern as `_openCreateDialog()` |
| `ResearchTab._openImportDialog()` | Presentation | MODIFY | Same pattern, passes `initialTab: 'research'` |
| `AddProjectCard` | Presentation | MODIFY | Add second action (import) or long-press/context menu |
| `AppDatabase` | Data | EXISTING | `getScanDirs()`, `setScanDirs()`, `upsertProjectSettings()` -- no changes |
| `projectsProvider` | Provider | EXISTING | `ref.invalidate()` after import -- no changes |

**Data Flow:**

```
User taps "Import" on Add+ card
  -> ImportProjectDialog opens
  -> macOS NSOpenPanel (file_selector getDirectoryPath)
  -> User picks existing folder
  -> importProject() validates folder
    -> optionally creates .planning/ scaffold (GSD skeleton)
    -> checks if folder is inside a scan dir
    -> if NOT inside a scan dir: adds parent dir to scan dirs via db.setScanDirs()
    -> persists projectType via db.upsertProjectSettings()
  -> Dialog pops with result
  -> Tab invalidates projectsProvider
  -> watcher picks up FS changes automatically
```

**Key Decision: Scan-Dir Expansion Strategy**

When the selected folder is NOT inside an existing scan dir, the importer must decide how to make it visible. Two options:

1. **Add the folder's parent as a new scan dir** -- Matches existing multi-dir scanning model. If user picks `/Users/rob/other/my-project`, add `/Users/rob/other/` as a scan dir. This also discovers sibling projects.

2. **Add the exact folder path as a scan dir** -- More surgical, but breaks the "scan dir contains projects as children" model that `_listProjectPaths` expects.

**Recommendation: Option 1** (add parent). It preserves the existing scanner architecture where scan dirs contain project subdirectories. The scanner already handles multi-dir via `getScanDirs()` and `WatcherService.multi()`. If the user wants only that one project, they can ignore siblings via ignore patterns.

**Integration with Existing CreateProjectDialog:**

The import dialog should be a separate widget (not merged into CreateProjectDialog) because the UX flow is fundamentally different:
- Create: name input -> toggles -> filesystem creation
- Import: folder picker -> detection of existing state -> optional scaffolding

However, the post-import action pattern (persist projectType, invalidate provider, open Terminal) is identical to CreateProjectDialog's flow and should reuse the same code path in the tabs.

### Feature 2: Detail-Panel Text Improvements

| Component | Layer | Status | Responsibility |
|-----------|-------|--------|----------------|
| `ProjectDetailPanel._buildBody()` | Presentation | MODIFY | Improved text rendering for BESCHREIBUNG section |
| `_SectionCard` | Presentation | MODIFY | Typography tweaks (optional) |

**Current State of Description Rendering (line 227-235 of project_detail_panel.dart):**

```dart
// Current: plain Text widget, single style
if (project.description != null)
  _SectionCard(
    colors: colors,
    accent: accent,
    title: 'BESCHREIBUNG',
    child: Text(
      project.description!,
      style: TextStyle(color: colors.textSec, fontSize: 14, height: 1.5),
    ),
  ),
```

**What Needs to Change:**

The `description` field comes from `GsdParser` which extracts a plain string from PROJECT.md. The text is rendered as a single unstyled paragraph. For long descriptions this becomes a wall of text.

Improvements (all within the existing widget, no new components):
1. **Line height increase**: `height: 1.5` -> `height: 1.7` for better readability
2. **Paragraph splitting**: Split on `\n\n` and render as separate `Text` widgets with spacing
3. **Max-lines with expand**: Show first ~5 lines with "Mehr anzeigen" toggle for very long descriptions
4. **Font size**: `fontSize: 14` is fine, add `letterSpacing: 0.1` for legibility
5. **Optional: Simple markdown rendering**: Bold (`**text**`) and bullet points via `TextSpan` parsing

**Recommended approach:** Replace the single `Text` widget with a `_DescriptionSection` stateful widget that:
- Splits on `\n\n` for paragraph breaks
- Supports `**bold**` via `TextSpan` parsing
- Supports `- bullet` lines with indentation
- Has expand/collapse for descriptions > 200 chars

This stays within the existing presentation layer -- no new providers or services.

### Feature 3: Memory Tab

| Component | Layer | Status | Responsibility |
|-----------|-------|--------|----------------|
| `MemoryTab` | Presentation | NEW | Grid/list of memory file cards with preview and actions |
| `MemoryFileCard` | Presentation | NEW | Individual memory card showing project name, content preview, staleness |
| `memoryFilesProvider` | Provider | NEW | FutureProvider that scans all memory files |
| `scanAllMemoryFiles()` | Service | NEW | Scan `~/.claude/projects/*/memory/MEMORY.md` |
| `MemoryFileModel` | Model | NEW | Project name, memory path, content preview, mtime, isStale |
| `ShellScreen._SideNav._items` | Presentation | MODIFY | Add Memory entry at index 4 |
| `ShellScreen.IndexedStack` | Presentation | MODIFY | Add MemoryTab(), Settings becomes index 5 |
| `watcherProvider` | Provider | EXISTING | Already watches `~/.claude/projects/`, auto-invalidates |

**Data Flow:**

```
MemoryTab builds
  -> ref.watch(memoryFilesProvider)
  -> scanAllMemoryFiles()
    -> list ~/.claude/projects/*/memory/MEMORY.md
    -> for each: decode project path from dir name
    -> read first ~500 chars as content preview
    -> compute isStale (>7 days)
    -> resolve project displayName by matching against projectsProvider
  -> returns List<MemoryFileModel>
  -> MemoryTab renders grid of MemoryFileCards

MemoryFileCard actions:
  - "rem-sleep" -> QuickActionsService.openRemSleep(projectPath)
  - "Im Editor oeffnen" -> Process.run('open', [memoryPath])
  - Tap card -> expand content preview or show full content in dialog
```

**Provider Architecture:**

```dart
// New provider -- follows exact pattern of projectsProvider
final memoryFilesProvider = FutureProvider<List<MemoryFileModel>>((ref) async {
  // Listen to watcher events (watcher already monitors ~/.claude/projects/)
  ref.listen(watcherProvider, (previous, next) {
    if (next.hasValue) {
      ref.invalidateSelf();
    }
  });

  return scanAllMemoryFiles();
});
```

This mirrors the existing `projectsProvider` pattern exactly: FutureProvider + ref.listen on watcherProvider for automatic invalidation.

**Project Path Decoding:**

The `encodeProjectPath()` function in `memory_reader.dart` converts `/Users/rob/code/my-app` to `-Users-rob-code-my-app`. The memory tab scanner needs the reverse: given a dir name like `-Users-rob-code-my-app`, derive the original project path. This is lossy (both `/` and `_` become `-`) but workable:

1. The dir name starts with `-Users-rob-` (known home dir prefix)
2. Cross-reference with `projectsProvider` data: for each memory dir, find the project whose `encodeProjectPath(project.path)` matches (or ends-with matches)
3. If no match, display the raw dir name as fallback

**NavigationRail Index Changes:**

Current indices: Code=0, Research=1, Tools=2, Agents=3, Settings=4
After: Code=0, Research=1, Tools=2, Agents=3, Memory=4, Settings=5

The `_SideNav._items` list gets a new entry. Settings remains pinned to bottom via the Spacer + manual NavItem pattern (line 186-197 of shell_screen.dart). This is a clean insertion -- no logic depends on hardcoded indices except the `_selectedIndex` state variable and the `IndexedStack` children list, which grow together.

## Patterns to Follow

### Pattern 1: Dialog-Returns-Action-Flags (from v1.3)
**What:** Dialog collects user intent, pops with a Map of flags. The tab (caller) executes the actual side effects after dialog closes.
**When:** Import dialog should return `{projectPath, projectType, wantsTerminal, wantsRemSleep}`.
**Why:** Avoids `mounted` lifecycle issues in dialog context. Proven pattern from CreateProjectDialog.

### Pattern 2: Top-Level Service Functions (from memory_reader, deletion_service)
**What:** `importProject()` as a top-level async function, not a class method.
**When:** Stateless operations that don't need injected dependencies.
**Why:** Consistent with `readMemoryData()`, `deleteProject()`, `createProject()`.

### Pattern 3: FutureProvider + ref.listen Invalidation (from projectsProvider)
**What:** `memoryFilesProvider` watches `watcherProvider` and self-invalidates on FS events.
**When:** Any provider that should refresh on filesystem changes.
**Why:** Established reactive pattern. The watcher already monitors `~/.claude/projects/`.

### Pattern 4: Nullable Model Fields (from ProjectModel)
**What:** `MemoryFileModel` uses nullable fields for optional data (`String? projectDisplayName`, `String? contentPreview`).
**When:** Data that may or may not be available depending on filesystem state.
**Why:** Consistent with `ProjectModel.gsd`, `ProjectModel.git`, `ProjectModel.memory`.

### Pattern 5: MarkdownBody with Custom StyleSheet for Memory Preview
**What:** Use `flutter_markdown_plus` MarkdownBody (not Markdown) for inline rendering without its own scroll.
**When:** Memory detail panel showing full MEMORY.md content.
**Example:**
```dart
MarkdownBody(
  data: content,
  styleSheet: MarkdownStyleSheet(
    p: TextStyle(color: colors.textPri, fontSize: 14, height: 1.6),
    h1: TextStyle(color: colors.textPri, fontSize: 20, fontWeight: FontWeight.w600),
    code: TextStyle(color: colors.cyan, fontFamily: 'monospace'),
    codeblockDecoration: BoxDecoration(
      color: colors.bgElev,
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Merging Import into CreateProjectDialog
**What:** Adding an "import existing" mode to the create dialog.
**Why bad:** CreateProjectDialog is already complex (300+ lines, tab switching, toggle management). Import has a fundamentally different flow (pick first, then configure). Merging creates a confusing multi-modal dialog.
**Instead:** Separate `ImportProjectDialog` widget. Share post-action code in the tab's handler method.

### Anti-Pattern 2: Adding Memory Tab Provider Dependency on projectsProvider
**What:** Making `memoryFilesProvider` depend on `projectsProvider` to resolve display names.
**Why bad:** Creates a dependency chain where memory tab can't load if project scanning fails. Memory files exist independently of whether their projects are in scan dirs.
**Instead:** `memoryFilesProvider` scans independently. If you want display names, do a best-effort match in the presentation layer (widget reads both providers).

### Anti-Pattern 3: Heavy Markdown Rendering for Description Section
**What:** Using `flutter_markdown_plus` for the detail-panel description section.
**Why bad:** Descriptions are short plain text from PROJECT.md. Full markdown rendering is overkill for a few paragraphs and adds visual inconsistency with the rest of the detail panel's custom-styled sections.
**Instead:** Lightweight hand-rolled parser using `TextSpan` for bold and manual bullet indentation. Reserve `flutter_markdown_plus` for the Memory tab where full MEMORY.md content benefits from proper markdown rendering.

### Anti-Pattern 4: Changing IndexedStack to Navigator
**What:** Replacing IndexedStack with a Navigator for the memory tab.
**Why bad:** IndexedStack preserves widget state across tab switches. Navigator would rebuild each tab on every visit.
**Instead:** Keep IndexedStack, just add the new tab. This is the established pattern.

### Anti-Pattern 5: Creating a New Window for Memory Preview
**What:** Opening memory preview in a separate macOS window.
**Why bad:** `desktop_multi_window` adds significant complexity. Inconsistent with existing detail panel pattern.
**Instead:** Use the same modal dialog pattern as `showProjectDetail()` -- slide-up + fade animation with `showGeneralDialog`.

## New Files Summary

| File | Layer | Purpose |
|------|-------|---------|
| `lib/features/memory/memory_tab.dart` | Presentation | Memory tab with grid of memory file cards |
| `lib/features/memory/memory_file_card.dart` | Presentation | Individual memory file card widget |
| `lib/data/models/memory_file_model.dart` | Model | Memory file data (path, preview, mtime, projectName) |
| `lib/data/services/memory_files_scanner.dart` | Service | Scan ~/.claude/projects/ for all MEMORY.md files |
| `lib/providers/memory_files_provider.dart` | Provider | FutureProvider for memory files list |
| `lib/features/shared/import_project_dialog.dart` | Presentation | Import existing folder dialog |
| `lib/data/services/import_service.dart` | Service | Validate + scaffold imported folder |

## Modified Files Summary

| File | Change | Scope |
|------|--------|-------|
| `shell_screen.dart` | Add Memory to _SideNav._items, add MemoryTab to IndexedStack, Settings index 4->5 | Small (~10 lines) |
| `code_tab.dart` | Add `_openImportDialog()` method, wire to Add+ card | Small (~30 lines) |
| `research_tab.dart` | Same as code_tab.dart | Small (~30 lines) |
| `project_detail_panel.dart` | Replace description Text with _DescriptionSection widget | Medium (~60 lines) |
| `add_project_card.dart` | Add import action (second button or context menu) | Small (~15 lines) |

## Build Order (Dependency-Driven)

```
Phase 1: Detail-Panel (zero dependencies, pure widget work)
  -> Modify project_detail_panel.dart
  -> No new providers, no new services
  -> Can be tested visually immediately

Phase 2: Folder Import (depends on existing DB + scanner)
  -> New: import_service.dart
  -> New: import_project_dialog.dart
  -> Modify: code_tab.dart, research_tab.dart, add_project_card.dart
  -> Leverages existing: AppDatabase.setScanDirs, projectsProvider invalidation

Phase 3: Memory Tab (depends on existing watcher + memory_reader)
  -> New: memory_file_model.dart
  -> New: memory_files_scanner.dart
  -> New: memory_files_provider.dart
  -> New: memory_tab.dart, memory_file_card.dart
  -> Modify: shell_screen.dart (new nav item + IndexedStack entry)
```

**Rationale:** Detail-panel first because it has zero dependencies and touches only one file. Folder import second because it extends the existing Add+ card flow (needs to work before Memory tab adds another nav destination). Memory tab last because it is fully self-contained and the nav index change should happen once at the end.

## Scalability Considerations

| Concern | Current Scale | v1.5 Impact |
|---------|--------------|-------------|
| Nav items | 5 (Code, Research, Tools, Agents, Settings) | 6 -- still fits in sidebar, no scroll needed |
| Memory files | ~22 projects scanned | ~22 memory dirs scanned -- same order of magnitude |
| Watcher dirs | scanDirs + ~/.claude/projects/ | No change -- watcher already monitors memory dir |
| DB tables | 2 (config, project_settings) | No change -- import uses existing tables |
| IndexedStack children | 5 widgets | 6 widgets -- negligible memory impact |

## Sources

- Direct codebase analysis of all files listed in this document (HIGH confidence)
- Existing patterns from v1.2 (Memory Indicator), v1.3 (Project Creator), v1.4 (Delete) (HIGH confidence)
- [flutter_markdown_plus on pub.dev](https://pub.dev/packages/flutter_markdown_plus) (MEDIUM confidence)
