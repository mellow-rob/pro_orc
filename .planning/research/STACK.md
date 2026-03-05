# Technology Stack

**Project:** Pro Orc v1.5 — Import, Detail-Panel & Memory-Tab
**Researched:** 2026-03-05
**Scope:** New dependencies only. Existing stack (Flutter 3.41.1, Riverpod 3.x, Drift v2, etc.) is validated and NOT re-researched.

---

## Existing Stack (Reference Only)

Already in `pubspec.yaml`, already working in production v1.4.1+6.

| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.41.1 | macOS app framework |
| Dart | ^3.11.0 | Language |
| flutter_riverpod | ^3.2.1 | State management |
| drift / drift_flutter | ^2.31.0 / ^0.2.8 | SQLite config DB |
| file_selector | ^1.1.0 | Native file/folder picker |
| watcher | ^1.2.1 | Filesystem watching |
| url_launcher | ^6.3.2 | External link opening |
| lucide_icons_flutter | ^3.1.9 | Icon set |

---

## New Dependencies for v1.5

### Only ONE new package needed: `flutter_markdown_plus`

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_markdown_plus | ^1.0.7 | Render MEMORY.md content as styled widgets in Memory-Tab preview | Official successor to Google's discontinued `flutter_markdown`. Maintained by Foresight Mobile. 140k+ weekly downloads. Minimal deps (markdown, meta, path — path already in pubspec). |

**Confidence:** HIGH — verified on pub.dev (published 2 months ago, v1.0.7).

---

## Feature-by-Feature Analysis

### 1. Folder Import (macOS Native Folder Picker)

**Verdict: NO NEW PACKAGE NEEDED**

`file_selector ^1.1.0` is already in pubspec.yaml and already used in two places:
- `settings_tab.dart:77` — `getDirectoryPath()` for adding scan dirs
- `code_tab.dart:219` — `getDirectoryPath()` for picking scan dir

The folder import feature calls the exact same `getDirectoryPath()` API. The picked path feeds into existing `db.addScanDir()` logic plus new auto-scaffolding. The `file_selector_macos` platform implementation confirmed supporting directory picking via native NSOpenPanel.

**Integration approach:**
```dart
import 'package:file_selector/file_selector.dart';

Future<void> importFolder() async {
  final dir = await getDirectoryPath();
  if (dir != null) {
    // 1. Auto-scaffold .planning/ if missing
    // 2. Add parent or dir itself to scan dirs via db
    // 3. Invalidate projectsProvider for live refresh
  }
}
```

**Confidence:** HIGH — verified in codebase, working in production since v1.1.

---

### 2. Markdown Rendering (Memory-Tab Preview)

**Verdict: ADD `flutter_markdown_plus ^1.0.7`**

Memory files (MEMORY.md) need to be rendered as styled markdown content in the new Memory-Tab. Raw text is unreadable for headers, lists, code blocks, and bold/italic formatting.

**Why `flutter_markdown_plus`:**
- Official Google handover — Foresight Mobile took over maintenance when Google discontinued the original `flutter_markdown` (May 2025)
- GitHub Flavored Markdown by default — matches GSD/memory file format
- Custom styling via `MarkdownStyleSheet` — critical for n3urala1 dark theme integration
- `MarkdownBody` widget renders inline without its own scroll — parent widget handles scrolling
- Minimal transitive deps: `markdown ^7.3.0`, `meta`, `path` (path already in pubspec)

**Integration approach:**
```dart
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

// In Memory-Tab preview panel:
MarkdownBody(
  data: memoryFileContent,
  styleSheet: MarkdownStyleSheet(
    p: TextStyle(color: colors.textPri, fontSize: 14, height: 1.6),
    h1: TextStyle(color: colors.textPri, fontSize: 20, fontWeight: FontWeight.w600),
    h2: TextStyle(color: colors.textPri, fontSize: 17, fontWeight: FontWeight.w500),
    code: TextStyle(color: colors.cyan, fontFamily: 'monospace', fontSize: 13),
    codeblockDecoration: BoxDecoration(
      color: colors.bgElev,
      borderRadius: BorderRadius.circular(8),
    ),
    listBullet: TextStyle(color: colors.textDim),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: colors.cyan, width: 3)),
    ),
  ),
)
```

**Confidence:** HIGH — verified on pub.dev, clear Google successor.

---

### 3. Detail-Panel Typography Improvements

**Verdict: NO NEW PACKAGE NEEDED**

The typography issue is a styling problem, not a package problem. Current `project_detail_panel.dart` uses these text styles:

| Element | Current | Issue |
|---------|---------|-------|
| Description text | fontSize: 14, height: 1.5 | Dense, hard to read long paragraphs |
| Section titles | fontSize: 10, letterSpacing: 1.5 | Fine as-is |
| Phase rows | fontSize: 13 | Acceptable |
| Decisions | fontSize: 12 | Tight for reading |

**Improvements achievable with pure Flutter TextStyle:**
- Bump description `height` from 1.5 to 1.65 for better line spacing
- Add paragraph breaks: split description on `\n\n`, render as separate `Text` widgets with `SizedBox(height: 12)` spacing
- Consider `SelectableText` for description to allow copy
- Increase decisions fontSize from 12 to 13
- Add `wordSpacing: 0.5` for body text readability

**No external packages needed.** Flutter's `TextStyle`, `SelectableText`, and layout widgets handle all typography improvements.

**Confidence:** HIGH — verified by reading project_detail_panel.dart implementation.

---

## Alternatives Considered and Rejected

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Folder picker | file_selector (existing) | file_picker | file_selector already works, is the official Flutter team package, already integrated in two places |
| Markdown rendering | flutter_markdown_plus | flutter_markdown (original) | Discontinued by Google May 2025, no longer maintained |
| Markdown rendering | flutter_markdown_plus | markdown_widget ^2.3.2 | Pulls 6 transitive deps (flutter_highlight, scroll_to_index, visibility_detector, etc.) — overkill for read-only preview of simple .md files |
| Markdown rendering | flutter_markdown_plus | gpt_markdown | Designed for AI chat output with LaTeX — unnecessary complexity for rendering memory files |
| Typography | Flutter built-in TextStyle | google_fonts | Would require bundled font files or network access; system fonts + TextStyle adjustments are sufficient |
| Typography | Flutter built-in TextStyle | auto_size_text | Detail panel has fixed layout with scroll container; auto-sizing text not applicable |
| Text display | SelectableText (built-in) | flutter_selectable_text | Flutter's built-in widget is sufficient for text selection |
| HTML rendering | NOT NEEDED | flutter_html | Memory files are Markdown, not HTML |

---

## Installation

```bash
cd pro_orc && flutter pub add flutter_markdown_plus
```

This adds to `pubspec.yaml`:
```yaml
dependencies:
  # ... existing deps unchanged ...
  flutter_markdown_plus: ^1.0.7   # NEW for v1.5 Memory-Tab
```

One command. One new dependency. No breaking changes to existing packages.

---

## What NOT to Add

| Package | Why Skip |
|---------|----------|
| file_picker | file_selector already works and is already integrated |
| google_fonts | System fonts are fine; adding Google Fonts requires bundled assets or network |
| flutter_markdown (original) | DISCONTINUED by Google — use flutter_markdown_plus instead |
| markdown_widget | 6 transitive deps for a simple preview — overkill |
| gpt_markdown | AI/LaTeX focused — wrong tool for the job |
| auto_size_text | Not applicable to scrollable detail panel layout |
| flutter_html | Memory files are Markdown, not HTML |
| flutter_widget_from_html | Same reason — not HTML content |

---

## Sources

- [file_selector on pub.dev](https://pub.dev/packages/file_selector) — v1.1.0, confirmed macOS directory picking support (HIGH confidence)
- [file_selector_macos on pub.dev](https://pub.dev/packages/file_selector_macos) — macOS platform implementation (HIGH confidence)
- [flutter_markdown_plus on pub.dev](https://pub.dev/packages/flutter_markdown_plus) — v1.0.7, Google's official successor (HIGH confidence)
- [flutter_markdown_plus: How We Took Over From Google](https://foresightmobile.com/blog/flutter-markdown-plus-google-handover) — Foresight Mobile blog on the handover (HIGH confidence)
- [markdown_widget on pub.dev](https://pub.dev/packages/markdown_widget) — v2.3.2+8, evaluated and rejected as too heavy (MEDIUM confidence)
- Codebase verification: `pubspec.yaml`, `settings_tab.dart:77`, `code_tab.dart:219`, `project_detail_panel.dart` (HIGH confidence)

---
*Stack research for: Pro Orc v1.5 — Import, Detail-Panel & Memory-Tab*
*Researched: 2026-03-05*
