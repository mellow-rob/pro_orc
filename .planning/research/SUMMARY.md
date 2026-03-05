# Research Summary: Pro Orc v1.5 — Import, Detail-Panel & Memory-Tab

**Domain:** Flutter macOS native desktop app — three feature additions to existing dashboard
**Researched:** 2026-03-05
**Overall Confidence:** HIGH

---

## Executive Summary

v1.5 adds three features to the Pro Orc dashboard: folder import (bring existing projects into the scanner), detail-panel typography improvements, and a new Memory-Tab for browsing MEMORY.md files. The research conclusion is that the existing architecture handles all three cleanly with minimal new dependencies. Only ONE new package is needed: `flutter_markdown_plus ^1.0.7` (Google's official successor to the discontinued `flutter_markdown`). Folder import reuses the already-integrated `file_selector` package, and typography improvements are pure Flutter `TextStyle` work.

The architecture is additive — 7 new files, 5 modified files, zero refactors. All three features follow patterns already proven in v1.2-v1.4: dialog-returns-action-flags for import, FutureProvider + ref.listen invalidation for the memory files provider, and top-level service functions for stateless operations. The Memory-Tab is the largest piece, introducing a master-detail split layout (project list + MEMORY.md content pane) rather than the card grid used by Code/Research tabs, which is the right call given the text-heavy nature of memory content.

The risk profile is low overall, but there are four critical pitfalls that must be addressed during implementation: (1) the watcher does not restart when scan dirs change at runtime, (2) markdown rendering defaults are unreadable on dark/glassmorphism backgrounds, (3) folder import can create duplicate projects when the imported folder is already inside a scan dir, and (4) NavigationRail integer indices will break Settings navigation when a new tab is inserted. All four have straightforward fixes identified in the research.

---

## Key Findings

### From STACK.md

- **flutter_markdown_plus ^1.0.7** — Only new dependency. Official Google handover to Foresight Mobile. GFM by default, custom `MarkdownStyleSheet` for dark theme, minimal transitive deps.
- **file_selector ^1.1.0** — Already in pubspec, already used in two places. No new package needed for folder import.
- **Typography** — Pure Flutter `TextStyle` + `SelectableText`. No external packages.
- **Rejected:** `markdown_widget` (6 transitive deps, overkill), `gpt_markdown` (LaTeX-focused), `google_fonts` (unnecessary), original `flutter_markdown` (discontinued).

### From FEATURES.md

**Table stakes (must-have):**
- Folder import: native macOS picker, auto-detect project type via existing `_inferType()`, scaffold GSD if missing, scan-dir expansion for folders outside known dirs, immediate appearance in correct tab
- Detail panel: line height bump to 1.6+, selectable text for descriptions, WCAG AA contrast verification
- Memory tab: project list with memory status, content preview, freshness indicator, rem-sleep action, open-in-editor action

**Differentiators (should-have):**
- Import preview showing detected state before confirming
- Master-detail split layout for Memory tab (not card grid)
- Collapsible long descriptions with "Mehr anzeigen"
- Projects-without-memory list with "rem-sleep starten" action

**Anti-features (do NOT build):**
- Memory editing in dashboard (read-only by design)
- Recursive folder scanning during import
- Full markdown renderer for short descriptions (use lightweight TextSpan parsing)
- Memory search/diff (defer to future version)
- Batch folder import
- Drag-and-drop import (defer — can be added later without architecture changes)

### From ARCHITECTURE.md

**Component boundaries are clean:**
- Folder Import: new `ImportProjectDialog` + `importProject()` service. Separate from `CreateProjectDialog` (different UX flow). Post-action code shared with create flow.
- Detail Panel: modify `ProjectDetailPanel._buildBody()` in place. New `_DescriptionSection` stateful widget for paragraph splitting + expand/collapse. No new providers.
- Memory Tab: new `MemoryTab`, `MemoryFileCard`, `MemoryFileModel`, `memoryFilesProvider`, `scanAllMemoryFiles()` service. Mirrors `projectsProvider` pattern exactly.

**Key architectural decision — scan-dir expansion:** When imported folder is outside known scan dirs, add the folder's **parent** as a new scan dir (not the folder itself). This preserves the existing scanner model where scan dirs contain project subdirectories.

**Key architectural decision — provider independence:** `memoryFilesProvider` must NOT depend on `projectsProvider`. Memory files exist independently of whether their projects are in scan dirs. Display name resolution happens in the presentation layer via best-effort matching.

### From PITFALLS.md

**Top 5 pitfalls with prevention:**

1. **Watcher does not restart for new scan dirs** (CRITICAL) — `watcherProvider` has `keepAlive()` and reads scan dirs only at init. After folder import adds a new scan dir, the watcher ignores it. Fix: `ref.invalidate(watcherProvider)` after `setScanDirs()`.

2. **Markdown default styles unreadable on dark glass** (CRITICAL) — `fromTheme()` adapts text but NOT decoration colors (blockquote backgrounds, code block backgrounds). Fix: build complete `MarkdownStyleSheet` from `AppColors` as a reusable factory method.

3. **Duplicate projects from parent/child scan dirs** (CRITICAL) — Importing a folder already inside an existing scan dir creates duplicates. Fix: validate path relationships before adding; show "Dieser Ordner wird bereits gescannt" warning.

4. **NavigationRail index mismatch** (CRITICAL) — Integer-based tab selection breaks when inserting Memory tab. Fix: refactor to enum-based tab selection (`AppTab { code, research, tools, agents, memory, settings }`).

5. **Memory tab sync file reads block UI** (MODERATE) — Existing `memory_reader.dart` uses sync ops. Reading 20+ MEMORY.md contents synchronously causes jank. Fix: async `readAsString()`, lazy loading on selection, truncated previews.

---

## Implications for Roadmap

### Suggested Phase Structure: 3 Phases

**Phase 1: Detail-Panel Typography**
- Rationale: Zero dependencies on other features. Touches only one existing file. Establishes text styling patterns reused by Memory Tab.
- Delivers: Readable descriptions (line height 1.6+), selectable text, paragraph splitting, expand/collapse for long descriptions, WCAG AA contrast verification.
- Features from FEATURES.md: All detail-panel table stakes + collapsible descriptions differentiator.
- Pitfalls to avoid: Markdown spacing breaking layout (Pitfall 8) — keep descriptions as lightweight TextSpan parsing, NOT full markdown. Reserve `flutter_markdown_plus` for Memory Tab.
- Estimated scope: ~60 lines modified in `project_detail_panel.dart`.

**Phase 2: Folder Import**
- Rationale: Self-contained feature extending existing Add+ card flow. Must ship before Memory Tab because imported projects need to work with live watching.
- Delivers: Native macOS folder picker, auto-detect project type, scaffold toggles for missing GSD/CLAUDE.md, scan-dir expansion with parent-dir strategy, duplicate detection.
- Features from FEATURES.md: All folder import table stakes. Import preview (differentiator) is a stretch goal.
- Pitfalls to avoid: Watcher not restarting (Pitfall 1), duplicate projects (Pitfall 3), scaffold overwriting existing files (Pitfall 7), picker cancel crash (Pitfall 9).
- New files: `import_project_dialog.dart`, `import_service.dart`. Modified: `code_tab.dart`, `research_tab.dart`, `add_project_card.dart`.

**Phase 3: Memory Tab**
- Rationale: Largest feature. Benefits from typography patterns (Phase 1) and working import flow (Phase 2). NavigationRail change should happen once at the end.
- Delivers: Master-detail memory browser, markdown-rendered MEMORY.md content, memory file cards with freshness, rem-sleep and open-in-editor actions, projects-without-memory list.
- Features from FEATURES.md: All memory tab table stakes + master-detail split + projects-without-memory list (differentiators).
- Pitfalls to avoid: Nav index mismatch (Pitfall 4 — refactor to enum first), sync reads blocking UI (Pitfall 5), memory path encoding edge cases (Pitfall 6), IndexedStack eagerness (Pitfall 11), accent color collision (Pitfall 10 — use existing `colors.violet`).
- New files: `memory_tab.dart`, `memory_file_card.dart`, `memory_file_model.dart`, `memory_files_scanner.dart`, `memory_files_provider.dart`. Modified: `shell_screen.dart`.
- New dependency: `flutter_markdown_plus ^1.0.7` (install at start of this phase).

### Phase Ordering Rationale

Detail-Panel first because it has zero dependencies, touches one file, and establishes the `MarkdownStyleSheet` factory pattern that Memory Tab reuses. Folder Import second because the watcher-restart fix (Pitfall 1) must be in place before Memory Tab exercises the full reactive chain. Memory Tab last because it is the largest, introduces the only new dependency, and the NavigationRail index refactor should happen once rather than incrementally.

---

## Research Flags

| Phase | Research Needed? | Rationale |
|-------|-----------------|-----------|
| Phase 1: Detail-Panel | NO | Standard Flutter TextStyle work. Patterns fully documented. |
| Phase 2: Folder Import | NO | Reuses existing `file_selector` and `ProjectCreatorService`. All integration points mapped. |
| Phase 3: Memory Tab | BRIEF | May need quick spike on `flutter_markdown_plus` MarkdownStyleSheet API to confirm all n3urala1 customizations work (blockquote decoration, code block styling). The package is well-documented but untested in this codebase. |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | One new dep, verified on pub.dev. All existing deps confirmed working in production v1.4. |
| Features | HIGH | All features scoped against codebase analysis. Table stakes / differentiators / anti-features clearly separated. |
| Architecture | HIGH | Component boundaries mapped to specific files and line numbers. All patterns proven in v1.2-v1.4. |
| Pitfalls | HIGH | 12 pitfalls identified with prevention strategies and recovery costs. Critical pitfalls have one-line fixes. |

### Gaps to Address During Planning

1. **MarkdownStyleSheet completeness** — Verify `flutter_markdown_plus` supports all needed customizations (blockquote decoration padding, table cell padding, horizontal rule color). Low risk but untested.
2. **Memory Tab accent color** — Research recommends violet (already in `AppColors`), but visual integration with glassmorphism backdrop needs design verification during implementation.
3. **Enum refactor scope** — Pitfall 4 recommends refactoring tab selection to enum. Need to confirm no other code references hardcoded tab indices (quick grep during Phase 3 planning).
4. **Import dialog placement** — Feature research recommends secondary action on Add+ card ("Importieren" below "+"). Final UX decision should happen during Phase 2 planning.

---

## "Looks Done But Isn't" Checklist (from Pitfalls)

- [ ] Import a folder, modify a file in it — verify live update (watcher restart)
- [ ] Import a folder already under existing scan dir — verify no duplicates
- [ ] Import a folder with existing `.planning/` — verify no overwrite
- [ ] Open folder picker and cancel — verify no crash
- [ ] View MEMORY.md with code blocks + blockquotes on dark background — verify readability
- [ ] View long description — verify quick actions still accessible
- [ ] Click Settings after adding Memory tab — verify correct tab opens
- [ ] App with 20+ projects — verify Memory tab loads without jank

---

## Sources

**Stack sources:**
- [flutter_markdown_plus on pub.dev](https://pub.dev/packages/flutter_markdown_plus) — v1.0.7 (HIGH)
- [Foresight Mobile: Google Handover Blog](https://foresightmobile.com/blog/flutter-markdown-plus-google-handover) (HIGH)
- [file_selector on pub.dev](https://pub.dev/packages/file_selector) — v1.1.0 (HIGH)
- Codebase: `pubspec.yaml`, `settings_tab.dart`, `code_tab.dart`, `project_detail_panel.dart` (HIGH)

**Architecture sources:**
- Direct codebase analysis of all integration points (HIGH)
- Established patterns from v1.2 (Memory Indicator), v1.3 (Project Creator), v1.4 (Delete) (HIGH)

**Pitfalls sources:**
- [flutter_markdown dark theme issue #82020](https://github.com/flutter/flutter/issues/82020)
- [flutter_markdown font brightness issue #162784](https://github.com/flutter/flutter/issues/162784)
- [file_picker macOS sandbox issue #1845](https://github.com/miguelpruivo/flutter_file_picker/issues/1845)
- [NavigationRail destination count issue #104913](https://github.com/flutter/flutter/issues/104913)
- Codebase: `shell_screen.dart`, `watcher_provider.dart`, `memory_reader.dart` (HIGH)

---
*Research synthesis completed: 2026-03-05*
*Ready for roadmap: yes*
