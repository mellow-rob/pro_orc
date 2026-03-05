# Feature Landscape

**Domain:** Dashboard enhancement — folder import, detail-panel typography, memory browser tab
**Researched:** 2026-03-05
**Confidence:** HIGH (all three features analyzed against existing codebase; patterns derived from code review of project_detail_panel.dart, create_project_dialog.dart, memory_reader.dart, shell_screen.dart)

---

## Table Stakes

Features users expect. Missing = product feels incomplete.

### Folder Import

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| macOS native Folder Picker dialog | Users expect OS-native file dialogs, not custom path input. `file_selector_macos` is Flutter's endorsed plugin. | Low | `file_selector_macos` is maintained by Flutter team; `file_picker` also works but heavier dependency |
| Auto-detect project type (Code vs Research) | Existing `_inferType()` already does this by checking for build files (pubspec.yaml, package.json). Import should reuse it, not ask the user. | Low | Call existing `_inferType()` on selected folder |
| Auto-scaffold GSD if missing | Imported project may lack `.planning/`. Offer toggles like CreateProjectDialog already does (GSD skeleton, CLAUDE.md). | Low | Reuse `ProjectCreatorService` scaffolding logic — skip folder creation step |
| Scan-dir expansion when folder is outside known dirs | If user picks `~/projects/foo` but only `~/code/` is a scan dir, the parent `~/projects/` must be added or the project won't appear. | Med | Check if selected path falls within existing scan dirs; if not, add parent dir to DB scan dirs with confirmation |
| Path validation (exists, is directory, not already tracked) | Prevent importing a folder that's already visible in the dashboard or doesn't exist. | Low | Check against current `projectsProvider` list by path |
| Immediate appearance in correct tab | After import, project must show up in Code or Research tab without manual refresh. | Low | Watcher invalidation already handles this — just invalidate `projectsProvider` |

### Detail Panel Text Readability

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Adequate line height (1.5-1.6x) | Current `height: 1.5` is set but text feels cramped in long descriptions on dark backgrounds. 1.6 is standard for dark-theme readability. | Low | Bump to `height: 1.6` in description Text widget |
| Sufficient contrast ratio | `textSec` on dark `bgSurf` must meet WCAG AA (4.5:1 for body text). Secondary text colors on dark themes often fail this. | Low | Verify `textSec` meets 4.5:1 contrast against `bgSurf`; bump alpha if needed |
| Selectable text for descriptions | Users expect to copy project descriptions. Current `Text` widget is not selectable. | Low | Switch to `SelectableText` in description section only |

### Memory Tab

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| List of all projects with memory files | Users expect to see which projects have consolidated memory. List with project name + last consolidated date. | Med | Scan `~/.claude/projects/*/memory/MEMORY.md` — reverse-decode paths to match projects |
| Memory file content preview | Users need to see what's in the memory without opening an editor. Plain text with monospace is sufficient. | Med | Read file contents at display time; markdown rendering optional |
| Memory freshness indicator | Already have stale/fresh/absent states on cards. Memory tab should show the same with explicit dates. | Low | Reuse `MemoryData.isStale` + `lastConsolidated` |
| rem-sleep quick action | One-click trigger for memory consolidation, same as card context menu. | Low | Reuse existing osascript Terminal automation |
| Open in editor action | Let user open MEMORY.md in their default editor. | Low | `Process.run('open', [memoryFilePath])` — same pattern as md file rows in detail panel |

---

## Differentiators

Features that set product apart. Not expected, but valued.

### Folder Import

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Import preview showing detected state | Before confirming, show what was detected: has `.planning/`? has `.git/`? has `CLAUDE.md`? Only offer scaffolding for missing items. Builds trust. | Med | Scan folder, diff against what scaffolding would add, display status |
| Drag-and-drop folder onto dashboard | macOS users expect drag-and-drop from Finder. Drop a folder onto the app window to trigger import. | Med | Flutter `DropTarget` widget at shell level; forwards to import flow |
| Import button integrated with Add+ card | Single Add+ card with two actions (create new / import existing) rather than a separate import card. Keeps the grid clean. | Low | Add secondary text or split-button to existing ghost card |

### Detail Panel Text Readability

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Basic inline formatting | Render **bold** and `code` spans (not full markdown). Descriptions from PROJECT.md often contain these. | Med | Manual regex parsing of `**text**` and backtick-code patterns into TextSpans |
| Collapsible long descriptions | Descriptions over ~4 lines collapse with "Mehr anzeigen" toggle. | Low | Reuse `_DecisionsSection` expand/collapse pattern already in detail panel |
| Improved section spacing | Tighter visual grouping within sections, more space between sections. Reduces wall-of-text feeling. | Low | Adjust padding values in `_SectionCard` |

### Memory Tab

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Master-detail split view | Left: project list with memory status. Right: full MEMORY.md content. Click to switch. Standard macOS browsing pattern (Finder, Mail, Notes). | Med | `Row` with fixed-width list + expanded detail pane |
| Memory statistics | Line count, section count (## headings), file size. Quick health overview per memory file. | Low | Parse MEMORY.md structure at read time |
| Projects-without-memory list | Show projects that lack memory alongside those that have it, with a "rem-sleep starten" action. Encourages consolidation. | Low | Filter `projectsProvider` for `memory == null` |

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Memory editing in dashboard | Pro Orc is read-only by design (Out of Scope: "Projekt-Editing in UI"). Memory files are managed by Claude's rem-sleep, not the user. Editing creates conflicts. | "Im Editor oeffnen" button that launches default text editor |
| Folder creation during import | Import means "bring existing folder into dashboard", not "create new folder". That's what CreateProjectDialog does. Mixing confuses the flow. | Keep import and create as separate actions on the Add+ card |
| Recursive folder scanning during import | Scanning subfolders of selected folder for nested projects adds complexity and confusion. One folder = one project. | Single folder selection per import action |
| Full markdown renderer for descriptions | Heavy dependency (`flutter_markdown`) for minimal benefit. Most descriptions are 1-3 sentences. | Selective formatting: bold + code spans via simple regex if needed |
| Memory file syncing or backup | Cloud sync is explicitly out of scope. Memory files live on the local filesystem only. | Show file path so user can manage backups themselves |
| Inline rem-sleep execution | Running rem-sleep inline (capturing output in dashboard) requires terminal emulation. | Open Terminal.app with rem-sleep command via osascript (existing pattern) |
| Search across memory files | Full-text search across all MEMORY.md files is high complexity for a niche use case. | Defer — ship basic browser first, add search if usage warrants it |
| Memory diff / change tracking | Showing what changed since last view requires persisting read timestamps per file in Drift DB. | Defer — the freshness indicator (stale/fresh) already communicates enough |
| Batch folder import | Selecting multiple folders at once adds iteration complexity for an initial-setup-only use case. | Single folder import; can be repeated quickly |

---

## Feature Dependencies

```
Folder Import:
  file_selector_macos (new dep)  --> Folder Picker Dialog
  _inferType() (existing)        --> Auto-detect project type
  ProjectCreatorService (existing) --> Auto-scaffold GSD/CLAUDE.md
  DB.addScanDir (existing)       --> Scan-dir expansion
  projectsProvider (existing)    --> Immediate appearance via invalidation

Detail Panel Text:
  project_detail_panel.dart (existing) --> Typography updates
  SelectableText (Flutter core)        --> Selectable text
  No new dependencies required

Memory Tab:
  memory_reader.dart (existing)  --> Memory file discovery + path decoding
  MemoryData model (existing)    --> Memory status (fresh/stale/absent)
  ShellScreen._SideNav (existing) --> New tab entry (index 5 or replaces existing)
  osascript automation (existing) --> rem-sleep action
  dart:io File.readAsString      --> Memory content reading
```

### Cross-Feature Dependencies

```
Folder Import --> Detail Panel (imported projects use the same detail panel)
Memory Tab --> Memory Indicator (card icons already show memory state; tab is the detail view)
Detail Panel Text --> Memory Tab (if memory content uses similar text styling)
```

---

## MVP Recommendation

Prioritize:

1. **Folder Import** — Table stakes only: native folder picker, auto-detect type, scaffold toggles for missing items, scan-dir expansion. Integrate as secondary action on existing Add+ card. Skip drag-and-drop and batch import.

2. **Detail Panel Text** — Quick wins with high impact: bump line height to 1.6, switch to `SelectableText` for descriptions, verify contrast ratio. Consider collapsible long descriptions using existing expand/collapse pattern.

3. **Memory Tab** — Master-detail split layout: left list of projects with memory (sorted by last consolidated), right pane showing MEMORY.md content as plain monospace text. Quick actions: rem-sleep trigger, open in editor. Include projects-without-memory in the list with "rem-sleep starten" action.

Defer:
- **Drag-and-drop import**: Power-user feature, adds complexity. Can be added later without architecture changes.
- **Inline markdown formatting in descriptions**: Low ROI for 1-3 sentence descriptions. Plain text with good typography is better than regex parsing complexity.
- **Memory search/diff**: High complexity, niche use case. Ship basic browser first.

---

## Implementation Notes

### Folder Import UX Flow

The recommended flow mirrors CreateProjectDialog but inverts the starting point:

1. User clicks "Importieren" action on Add+ card (secondary action below the "+" icon)
2. macOS native folder picker opens (`file_selector_macos`)
3. Selected folder is analyzed: has `.planning/`? `pubspec.yaml`/`package.json`? `.git/`? `CLAUDE.md`?
4. Import dialog shows: folder name, detected type (Code/Research), detected features with checkmarks
5. Toggles for what to scaffold (only items that are missing): GSD skeleton, CLAUDE.md, .gitignore
6. If folder is outside scan dirs: confirmation prompt to add parent as scan dir
7. "Importieren" button creates scaffolding, adds scan dir if needed, persists projectType in DB, invalidates provider
8. Project appears in correct tab

Key decisions:
- **Import button placement**: Add to existing Add+ card as secondary text ("Importieren" below the "+" icon, ghost-style). Do NOT create a separate ghost card — two ghost cards would look cluttered.
- **Scan dir handling**: If imported folder's parent is already a scan dir, no change needed. If not, prompt: "Ordner X ist nicht in einem Scan-Verzeichnis. Y als Scan-Verzeichnis hinzufuegen?"
- **Already-tracked detection**: Check `projectsProvider` results for matching `path`. Show "Projekt wird bereits angezeigt" warning if found.
- **DB projectType persistence**: Set immediately on import (matching CreateProjectDialog pattern) to bypass `_inferType()` heuristic for folders that might not have build files yet.

### Detail Panel Typography

Current state from code review:
- Description: `TextStyle(color: colors.textSec, fontSize: 14, height: 1.5)` — decent baseline
- Panel: max-width 700px, 24px horizontal padding = 652px text width — good for readability
- `_SectionCard`: 14px all-around padding, accent top border — clean containers

Recommended changes (minimal, high-impact):
1. `height: 1.5` --> `height: 1.6` for breathing room on dark backgrounds
2. `Text` --> `SelectableText` for description section only
3. Verify `textSec` alpha against `bgSurf` for WCAG AA compliance (4.5:1 ratio)
4. Consider `letterSpacing: 0.15` on description text for dark-theme legibility
5. Add `maxLines` + "Mehr anzeigen" for descriptions exceeding ~6 lines

### Memory Tab Architecture

The tab should follow existing tab patterns (CodeTab, ResearchTab) but use a **master-detail split** instead of a card grid, because memory content is text-heavy and benefits from a reading pane.

```
+-------------------+------------------------------------+
| Projekt-Liste     | MEMORY.md Inhalt                   |
|                   |                                    |
| [brain] pro-orc   | # Pro Orc Memory                   |
|   03.03.2026      |                                    |
|   [frisch]        | ## Project State                   |
|                   | - v1.4: shipped 2026-03-01         |
|                   |                                    |
| > flutter-app     | ## Architecture Essentials          |
|   28.02.2026      | - Three-layer: Presentation...     |
|   [stale]         |                                    |
|                   | ## Key Gotchas                     |
| ---- Ohne Memory -| - Claude path encoding is...       |
| [zzz] my-tool     |                                    |
|   rem-sleep       |                                    |
+-------------------+------------------------------------+
```

**Provider**: New `memoryBrowserProvider` that combines `projectsProvider` data with memory file reading. Returns list of `(ProjectModel, String? memoryFilePath, String? memoryContent)` tuples. Sorted: projects with memory first (by lastConsolidated desc), then projects without memory (alphabetical).

**Tab accent color**: The sidebar uses cyan for all nav items. Memory tab can use the same accent, or consider amber/gold for "brain" warmth. With 5+ tabs already using cyan, amber could help visual differentiation.

**Tab placement in NavigationRail**: Current tabs are Code (0), Research (1), Tools (2), Agents (3), Settings (4). Memory could be index 4, pushing Settings to 5. The icon should NOT be `LucideIcons.brain100` (already used for Tools). Use `LucideIcons.bookOpen100` or `LucideIcons.fileHeart100` instead to avoid icon collision.

---

## Sources

- Codebase analysis: `project_detail_panel.dart` (detail panel structure, current typography), `create_project_dialog.dart` (project creation UX, scaffold toggles), `memory_reader.dart` (path encoding, memory detection), `shell_screen.dart` (navigation structure, tab indexing), `project_model.dart` (data model with memory field)
- Flutter `file_selector` endorsed plugin for macOS native file dialogs (pub.dev)
- WCAG 2.1 AA contrast requirements (4.5:1 for normal text on any background)
- macOS master-detail layout pattern (standard in Finder, Mail, Notes, Xcode)
- Existing patterns: `_DecisionsSection` expand/collapse, `_MdFileRow` file opening, osascript Terminal automation

---
*Feature research for: Pro Orc v1.5 — Import, Detail-Panel & Memory-Tab*
*Researched: 2026-03-05*
