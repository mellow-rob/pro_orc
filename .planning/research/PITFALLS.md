# Domain Pitfalls — v1.5 Milestone

**Domain:** Adding folder import, detail-panel overhaul, and memory tab to existing Flutter macOS dashboard (Pro Orc)
**Researched:** 2026-03-05
**Confidence:** HIGH for integration pitfalls (verified against actual codebase). MEDIUM for markdown rendering specifics (WebSearch + official docs, not Context7-verified).

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or broken user-facing features.

---

### Pitfall 1: WatcherProvider Does Not Restart When Scan Dirs Change

**What goes wrong:** The `watcherProvider` is a `StreamProvider` with `ref.keepAlive()` that reads scan dirs from the database at initialization time, creates a `WatcherService.multi(allDirs)`, and then yields its events forever. When a user imports a new folder (adding a new scan directory), `projectsProvider` is invalidated and re-scans correctly, but the watcher is never recreated because it has `keepAlive()`. The new folder is scanned once but never watched for live updates. The user sees the imported project appear but subsequent changes in that folder are invisible until app restart.

**Why it happens:** The watcher was designed as a permanent singleton in v1.1 (per CONTEXT.md: "keepAlive: never disposed, locked decision"). This was correct when scan dirs were static. Folder import makes scan dirs dynamic at runtime.

**Consequences:** Imported projects appear stale. Users think the app is broken because other projects update in real-time but the imported one does not.

**Prevention:**
- When `_saveScanDirs()` completes in settings (or after folder import), also `ref.invalidate(watcherProvider)` to force recreation with the new directory list
- The old `WatcherService` will be disposed via `ref.onDispose(service.dispose)`, so no resource leak
- Test: import a folder, modify a file in it, verify the dashboard updates without app restart
- Alternative: add a method to `WatcherService` to dynamically add a directory to the existing multi-watcher instead of full recreation

**Detection:** Dashboard shows imported project but does not reflect file changes made after import.

**Phase to address:** Folder Import phase. This is the first thing to verify after implementing the import flow.

---

### Pitfall 2: Markdown Rendering on Dark Background — Default Styles Are Unreadable

**What goes wrong:** Flutter's `flutter_markdown` package (and similar packages like `markdown_widget`) uses `MarkdownStyleSheet.fromTheme()` which pulls from the app's `ThemeData`. However, several elements have hardcoded light-theme assumptions:
1. **Blockquote background** defaults to `Colors.blue.shade100` (bright light blue) — confirmed open issue flutter/flutter#82020
2. **Code block background** defaults to a light gray that disappears against dark surfaces
3. **Table borders** default to dark colors that are invisible on dark backgrounds
4. **Link colors** may default to Material blue which clashes with the n3urala1 cyan/fuchsia palette

For Pro Orc's glassmorphism dark theme with translucent backgrounds, the default stylesheet will produce text blocks that look broken — bright rectangles floating over the dark glass cards.

**Why it happens:** `flutter_markdown` was designed for light themes first. The `fromTheme` constructor adapts text colors but NOT decoration colors (backgrounds, borders). These require explicit `MarkdownStyleSheet` overrides.

**Consequences:** Memory tab showing MEMORY.md content will have garish light-colored blockquotes and code blocks. Detail panel description text (if rendered as markdown) will clash with the glass card background.

**Prevention:**
- Build a `MarkdownStyleSheet` that explicitly sets every decoration property using `AppColors`:
```dart
MarkdownStyleSheet(
  // Text colors from theme
  p: TextStyle(color: colors.textPri, fontSize: 14, height: 1.6),
  h1: TextStyle(color: colors.textPri, fontSize: 20, fontWeight: FontWeight.w600),
  // Code blocks — dark elevated surface
  codeblockDecoration: BoxDecoration(
    color: colors.bgElev.withValues(alpha: 0.8),
    borderRadius: BorderRadius.circular(8),
  ),
  code: TextStyle(color: colors.cyan, fontFamily: 'SF Mono', fontSize: 13),
  // Blockquote — accent-tinted container
  blockquoteDecoration: BoxDecoration(
    color: colors.cyan.withValues(alpha: 0.06),
    border: Border(left: BorderSide(color: colors.cyan.withValues(alpha: 0.4), width: 3)),
    borderRadius: BorderRadius.circular(4),
  ),
  // Table
  tableBorder: TableBorder.all(color: colors.textDim.withValues(alpha: 0.3)),
  // Links
  a: TextStyle(color: colors.cyan, decoration: TextDecoration.underline),
)
```
- Create this stylesheet as a reusable factory method (e.g., `AppColors.markdownStyle()`) to ensure consistency across detail panel and memory tab
- Test with real MEMORY.md files that contain code blocks, blockquotes, headers, and links

**Detection:** Any bright-colored rectangle or invisible text in the markdown rendering area.

**Phase to address:** Detail-Panel phase (before Memory Tab, since Memory Tab will reuse the same stylesheet).

---

### Pitfall 3: Folder Import Creates Duplicate Projects When Folder Is Already Inside a Scan Dir

**What goes wrong:** User imports `/Users/rob/code/my-project` via the folder picker. If `/Users/rob/code` is already a scan directory, `my-project` is already being scanned as a child. Adding `/Users/rob/code/my-project` as a new scan dir creates a duplicate — the project appears twice in the dashboard (once from the parent scan dir, once from the new explicit scan dir).

**Why it happens:** `ProjectScanner.scanAll()` loops through `db.getScanDirs()` and scans each directory for project subdirectories. It does not deduplicate by absolute path across scan directories. The existing `_addScanDir` in settings also does not check for parent/child relationships.

**Consequences:** Duplicate cards in the dashboard. If the user then deletes one via the delete dialog, it only removes from one scan source. Confusion and data inconsistency.

**Prevention:**
- Before adding a new scan dir, check two conditions:
  1. The folder is not already a direct child of an existing scan dir (parent check)
  2. No existing scan dir is a child of the new folder (child check — importing a parent would subsume existing specific dirs)
- Show appropriate feedback: "Dieser Ordner wird bereits gescannt (ueber ~/code)" or "Dieser Ordner enthaelt bereits gescannte Verzeichnisse"
- For the "folder is already scanned" case: still allow import but skip adding to scan dirs — just run auto-scaffolding on the existing project
- For the "importing a parent" case: warn that this will also scan many other projects

**Detection:** Same project name appears twice in the Code or Research tab grid.

**Phase to address:** Folder Import phase. Add validation before modifying scan dirs.

---

### Pitfall 4: NavigationRail Index Mismatch After Adding Memory Tab

**What goes wrong:** The current `_SideNav` uses a static `_items` list with 4 entries (Code=0, Research=1, Tools=2, Agents=3) and Settings as a special trailing item at index 4. The `IndexedStack` has 5 children. Adding a Memory tab means either:
- Inserting it into `_items` (shifting indices of everything after it)
- Appending it at the end (before Settings)

If the Memory tab is inserted at position 3 (between Tools and Agents), Agents becomes index 4, Settings becomes index 5. Any hardcoded `selectedIndex == 4` for Settings breaks. The `onSelect(4)` for Settings now points to Agents.

**Why it happens:** The shell uses integer indices for tab selection rather than an enum or named constants. This is fragile when adding new tabs.

**Consequences:** Clicking Settings opens Agents tab. Or clicking the new Memory tab opens something else entirely. Silent wrong behavior — no crash, just incorrect navigation.

**Prevention:**
- Refactor tab selection to use an enum:
```dart
enum AppTab { code, research, tools, agents, memory, settings }
```
- Replace `_selectedIndex` int with `AppTab _selectedTab`
- Map each enum value to its `IndexedStack` child position
- This makes adding a new tab safe — just add the enum value and its widget, ordering is handled by the enum-to-index mapping
- If refactoring to enum feels heavy, at minimum define constants: `static const kSettingsIndex = 5;` and update all references when adding the tab

**Detection:** Settings button opens wrong tab after adding Memory tab.

**Phase to address:** Memory Tab phase. Refactor the index system BEFORE adding the new tab widget.

---

## Moderate Pitfalls

---

### Pitfall 5: Memory Tab File Reading Blocks the UI Thread

**What goes wrong:** The memory tab needs to read and display MEMORY.md file contents. The existing `memory_reader.dart` uses sync file operations (`existsSync`, `statSync`, `listSync`) because "not hot path, per-project check, simpler code" (per Key Decisions). But the Memory tab will need to read the actual file content of potentially 20+ MEMORY.md files for preview. Reading file contents synchronously on the main isolate will cause jank — especially if memory files are large (some MEMORY.md files can be 10KB+).

**Why it happens:** The existing memory reader was designed for existence checks only (`existsSync` + `statSync`), not content reading. Extending it to read content without switching to async will block the UI.

**Prevention:**
- Use `File.readAsString()` (async) for content reading, even if the existence check remains sync
- Consider reading content lazily — only when the user expands/selects a memory file in the tab, not all at once
- If showing previews for all memory files, use a `FutureProvider` or compute the previews in batches
- Truncate preview to first N lines (e.g., 20 lines) to avoid reading entire large files

**Detection:** UI freezes briefly when switching to the Memory tab, especially with many projects.

**Phase to address:** Memory Tab phase.

---

### Pitfall 6: Memory Path Encoding Edge Cases With Imported Projects

**What goes wrong:** Claude's memory path encoding replaces both `/` and `_` with `-`. The existing `encodeProjectPath()` handles this. But imported projects may be anywhere on the filesystem, not just under `~/code/` or `~/project_orchestration/`. Edge cases:
1. Paths with double hyphens (e.g., `/Users/rob/my--project`) — encoding is ambiguous
2. Paths with spaces (e.g., `/Users/rob/My Project`) — Claude may encode these differently
3. Very long paths — the `maxDirLen` constraint in fuzzy matching may reject valid matches
4. Paths under unusual locations (e.g., `/Volumes/External/projects/foo`) — encoding produces very long dir names

The existing fuzzy matching uses `maxDirLen = encodedPath.length + 10` which was tuned for `~/code/` paths. Imported projects from other locations may have different Claude encoding patterns.

**Why it happens:** The memory reader was built for a known set of project locations. Folder import makes project locations unpredictable.

**Prevention:**
- Test memory detection with imported projects from non-standard paths
- Consider increasing `maxDirLen` tolerance for imported projects, or making it configurable
- Add a fallback: if no memory is found via path encoding, scan all Claude project directories and check if any contain the project's basename as a suffix
- Log (debug-level) which strategy matched for memory detection — aids debugging when users report missing memory indicators

**Detection:** Imported projects never show memory indicators even when MEMORY.md exists in `~/.claude/projects/`.

**Phase to address:** Memory Tab phase (since it will exercise memory detection more heavily than the indicator).

---

### Pitfall 7: Auto-Scaffolding on Import Overwrites Existing .planning Files

**What goes wrong:** The folder import feature includes "Auto-Scaffold" — creating `.planning/PROJECT.md`, `STATE.md`, `ROADMAP.md` if they don't exist. But "don't exist" is a tricky check. The project may have `.planning/` with some files but not others. Or it may have GSD files in a different layout (e.g., `docs/` instead of `.planning/`). Blindly checking for `.planning/PROJECT.md` and creating it if absent could:
1. Create a partial scaffold alongside existing planning docs
2. Miss that the project already has GSD data in a different location

**Why it happens:** The `GsdParser` already handles multiple fallback paths, but the scaffold creator may not be aware of these fallbacks.

**Prevention:**
- Before scaffolding, run `GsdParser.parse()` on the imported directory
- If `GsdData.isEmpty` is false, skip scaffolding entirely — the project already has planning data
- If empty, check for existing `.planning/` directory — if it exists with any files, ask the user before creating new ones
- Show a preview of what will be created: "Folgende Dateien werden erstellt: PROJECT.md, STATE.md, ROADMAP.md"
- Never overwrite existing files

**Detection:** User imports a project and their existing planning docs are supplemented with empty templates, confusing the GSD status display.

**Phase to address:** Folder Import phase.

---

### Pitfall 8: Detail Panel Description Overhaul Breaks Existing Card Layout

**What goes wrong:** The v1.5 goal includes "Detail-Panel Beschreibungstexte lesbar machen." The current `_SectionCard` for "BESCHREIBUNG" renders `project.description` as plain `Text` with `fontSize: 14, height: 1.5`. If this is changed to markdown rendering (to support formatting in descriptions), the widget height changes unpredictably. Descriptions that were 2 lines of plain text may expand to 5+ lines with markdown paragraph spacing. This pushes the scrollable content down, potentially hiding the quick actions row below the fold.

**Why it happens:** Plain text and markdown rendering have different line height, paragraph spacing, and block element padding behaviors. What looks compact as plain text becomes spacious as rendered markdown.

**Prevention:**
- If switching to markdown rendering: constrain the description section with a `ConstrainedBox(maxHeight: ...)` and make it independently scrollable, OR
- Keep description as plain text and only use markdown rendering in the Memory tab where content is expected to be long
- If markdown is used: explicitly set `MarkdownStyleSheet` paragraph spacing to match current `height: 1.5` — default markdown paragraph spacing is larger
- Test with real project descriptions of varying lengths (1 line to 20+ lines)

**Detection:** Detail panel looks spacious/empty for short descriptions, or quick actions disappear below fold for long ones.

**Phase to address:** Detail-Panel phase.

---

### Pitfall 9: file_selector getDirectoryPath Returns null Without Error on Cancel

**What goes wrong:** The existing `_addScanDir()` in settings already uses `getDirectoryPath()` from `file_selector` correctly (null check on result). But the folder import flow is more complex — it may chain operations after the picker: validate path, check for duplicates, run scaffolding, add to scan dirs, invalidate providers. If any step in this chain assumes the path is non-null because "the picker was shown," it will crash when the user cancels the picker.

**Why it happens:** Developers focus on the happy path (user selects a folder) and forget that cancel returns null, not an exception.

**Prevention:**
- Return early on null immediately after `getDirectoryPath()`, before any other logic
- Do not show "importing..." loading state before the picker returns — the user may cancel
- If using a dialog with the picker, do not close the dialog on picker launch (user may cancel and expect to be back in the dialog)

**Detection:** App crashes or shows error when user opens folder picker then clicks Cancel.

**Phase to address:** Folder Import phase.

---

### Pitfall 10: Memory Tab Accent Color Collision With Existing Tabs

**What goes wrong:** The existing color scheme uses cyan for Code tab, fuchsia for Research tab. If the Memory tab reuses cyan or fuchsia, it becomes visually indistinguishable from an existing tab. If it uses a new color (e.g., violet — already used for memory indicators), that color needs to be added to `AppColors` ThemeExtension and may clash with the glassmorphism backdrop.

**Why it happens:** The n3urala1 color system was designed for two primary accents. Adding a third requires careful palette integration.

**Prevention:**
- Use violet/purple for the Memory tab — it is already associated with memory via the `MemoryIndicator` (which uses `colors.violet` for fresh memory state)
- Verify `colors.violet` exists in `AppColors` already (it does, used by `MemoryIndicator`)
- Test the violet accent against the glassmorphism backdrop — ensure sufficient contrast
- Keep the same `withValues(alpha: 0.06)` and `withValues(alpha: 0.1)` patterns used by other tab accents for consistency

**Detection:** Memory tab looks identical to another tab, or its accent color is invisible against the dark glass background.

**Phase to address:** Memory Tab phase (UI design decision needed before building the tab).

---

## Minor Pitfalls

---

### Pitfall 11: IndexedStack Keeps All Tab Widgets Alive — Memory Tab May Be Expensive

**What goes wrong:** `ShellScreen` uses `IndexedStack` which builds ALL children but only displays one. The Memory tab will read file contents, parse markdown, and potentially render many widgets. All of this happens even when the user is on the Code tab and has never opened the Memory tab.

**Prevention:**
- Use lazy initialization inside the Memory tab — only load content on first build or when `selectedIndex` matches
- Or wrap the Memory tab in a builder that defers initialization:
```dart
IndexedStack(
  index: _selectedIndex,
  children: [
    CodeTab(),
    ResearchTab(),
    ClaudeToolsTab(),
    AgentsTab(),
    _selectedIndex >= 4 ? MemoryTab() : const SizedBox.shrink(),
    SettingsTab(),
  ],
)
```
- But note: `SizedBox.shrink()` in `IndexedStack` means the tab loses state when switching away. Better approach is lazy load inside the tab widget itself using a `_initialized` flag.

**Phase to address:** Memory Tab phase.

---

### Pitfall 12: Markdown Package Selection — flutter_markdown vs markdown_widget

**What goes wrong:** `flutter_markdown` (official Flutter package) is simpler but has known dark theme issues and limited customization. `markdown_widget` is more flexible but adds a heavier dependency. Choosing the wrong one leads to either fighting dark theme issues or over-engineering the markdown rendering.

**Prevention:**
- Use `flutter_markdown` — it is the official package, sufficient for rendering MEMORY.md previews, and the dark theme issues are solvable with a custom `MarkdownStyleSheet` (see Pitfall 2)
- Do NOT use `markdown_widget` unless `flutter_markdown` proves insufficient after trying the stylesheet approach
- Pin to a specific version to avoid breaking changes

**Phase to address:** Detail-Panel phase (when first introducing markdown rendering).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Folder Import | Watcher not restarted for new dir (Pitfall 1) | Invalidate `watcherProvider` after adding scan dir |
| Folder Import | Duplicate projects from parent/child scan dirs (Pitfall 3) | Validate path relationships before adding |
| Folder Import | Scaffold overwrites existing planning docs (Pitfall 7) | Check `GsdParser` result before scaffolding |
| Folder Import | Cancel on picker crashes chain (Pitfall 9) | Early return on null |
| Detail-Panel | Markdown blocks unreadable on dark glass (Pitfall 2) | Build custom `MarkdownStyleSheet` from `AppColors` |
| Detail-Panel | Markdown spacing breaks layout (Pitfall 8) | Constrain height or keep plain text for descriptions |
| Memory Tab | Index mismatch breaks Settings nav (Pitfall 4) | Refactor to enum-based tab selection |
| Memory Tab | Sync file reads block UI (Pitfall 5) | Async reads, lazy loading, truncated previews |
| Memory Tab | Imported project memory not detected (Pitfall 6) | Test non-standard paths, increase `maxDirLen` |
| Memory Tab | IndexedStack loads all tabs (Pitfall 11) | Lazy initialization pattern |
| Memory Tab | Accent color collision (Pitfall 10) | Use existing `colors.violet` |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Folder import + watcher | Assuming watcher auto-detects new scan dirs | Explicitly invalidate `watcherProvider` after `setScanDirs()` |
| Folder import + scanner | Not deduplicating when imported folder is child of existing scan dir | Check parent/child relationships before adding |
| Markdown + glassmorphism | Using `fromTheme()` without overriding decoration colors | Build full `MarkdownStyleSheet` with explicit dark-aware decorations |
| New nav tab + IndexedStack | Using integer indices for tab routing | Use enum-based tab selection to prevent index drift |
| Memory tab + memory reader | Extending sync reader to read file content | Use async `readAsString()` for content, keep sync for existence |
| Auto-scaffold + existing projects | Blindly creating template files | Check `GsdParser` results before scaffolding |

---

## "Looks Done But Isn't" Checklist

- [ ] **Folder import:** Import a folder, then modify a file in it — verify live update works (watcher restart)
- [ ] **Folder import:** Import a folder that is already under an existing scan dir — verify no duplicate cards
- [ ] **Folder import:** Import a folder with existing `.planning/` — verify no files overwritten
- [ ] **Folder import:** Open picker and cancel — verify no crash or error state
- [ ] **Markdown rendering:** View a MEMORY.md with code blocks, blockquotes, headers — verify all readable on dark background
- [ ] **Markdown rendering:** View a long description — verify quick actions still accessible (scroll or constrain)
- [ ] **Memory tab:** Click Settings icon — verify it still opens Settings (not Agents or Memory)
- [ ] **Memory tab:** Switch to Code tab, modify a file, switch back to Memory — verify no stale state
- [ ] **Memory tab:** Import a project from `/Volumes/External/...` — verify memory indicator works
- [ ] **Memory tab:** App has 20+ projects — verify Memory tab does not cause jank on first load

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Watcher not restarted (1) | LOW | Add `ref.invalidate(watcherProvider)` to scan dir save — one line fix |
| Markdown dark theme (2) | LOW | Create `MarkdownStyleSheet` factory — mechanical, no logic changes |
| Duplicate projects (3) | MEDIUM | Add path validation logic, update UI to show warning — testable in isolation |
| Nav index mismatch (4) | LOW-MEDIUM | Refactor to enum — mechanical but touches shell_screen + any direct index references |
| Sync file reads (5) | LOW | Switch to async `readAsString` — straightforward refactor |
| Memory path encoding (6) | MEDIUM | Requires testing with diverse paths, may need heuristic tuning |
| Scaffold overwrites (7) | LOW | Add existence check before file creation — simple guard |
| Layout break from markdown (8) | LOW | Constrain height or revert to plain text — quick decision |
| Picker cancel crash (9) | LOW | Add null guard — one line fix |
| Accent color (10) | LOW | Use existing violet — design decision, not code change |

---

## Sources

- [flutter_markdown blockquoteDecoration dark theme issue #82020](https://github.com/flutter/flutter/issues/82020)
- [flutter_markdown font color theme brightness issue #162784](https://github.com/flutter/flutter/issues/162784)
- [MarkdownStyleSheet API docs](https://pub.dev/documentation/flutter_markdown/latest/flutter_markdown/MarkdownStyleSheet-class.html)
- [Material 3 Theme for Markdown (Rody Davis gist)](https://gist.github.com/rodydavis/01a87320cf8522241515507e5ee53ac5)
- [file_picker macOS sandbox-off issue #1845](https://github.com/miguelpruivo/flutter_file_picker/issues/1845)
- [file_selector package](https://pub.dev/packages/file_selector)
- [NavigationRail hard destination count issue #104913](https://github.com/flutter/flutter/issues/104913)
- [watcher package — directory event limitations](https://github.com/dart-lang/watcher/issues/1)
- Codebase analysis: `shell_screen.dart`, `watcher_provider.dart`, `app_database.dart`, `settings_tab.dart`, `project_detail_panel.dart`, `memory_reader.dart`, `memory_indicator.dart`

---
*Pitfalls research for: Pro Orc v1.5 — Folder Import, Detail-Panel, Memory Tab*
*Researched: 2026-03-05*
