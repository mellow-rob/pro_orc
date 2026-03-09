# Phase 22: Claude-Button - Research

**Researched:** 2026-03-09
**Domain:** Flutter UI modification (card widgets, quick actions, context menu)
**Confidence:** HIGH

## Summary

Phase 22 is a focused UI restructuring task: promote Claude Code launch to the primary action on all project cards, visually differentiate it from other quick actions, and relocate the current Terminal button to the context menu to avoid function loss.

The existing codebase already contains all necessary infrastructure. `QuickActionsService.openClaudeWithPrompt()` handles the osascript-based Terminal launch with `claude` command. The pattern for adding context menu items is established in `project_context_menu.dart`. The theme system provides `colors.cyan` for visual emphasis.

**Primary recommendation:** Add a new `openClaude(projectPath)` method to `QuickActionsService` (without prompt, just `cd && claude`), create a prominent Claude button widget separate from the quick action row, move Terminal to context menu, and update both card types.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLB-01 | User kann auf jeder Projektkarte einen prominenten Claude-Button klicken der eine Claude Code Session im Terminal im Projektverzeichnis startet | Existing `_terminalScript` pattern + new `openClaude()` method in QuickActionsService |
| CLB-02 | Claude-Button ist visuell hervorgehoben (Cyan, groesser) und als primaere Action auf der Karte erkennbar | AppColors.cyan available, separate widget with larger sizing outside quick action row |
| CLB-03 | Bisheriger Terminal-Button wird durch Claude-Button ersetzt; Terminal-Zugang bleibt ueber Kontextmenue oder sekundaere Action erreichbar | Add 'Terminal' item to `showProjectContextMenu()` in `project_context_menu.dart` |
</phase_requirements>

## Standard Stack

### Core

No new dependencies. Everything builds on existing stack:

| Library | Version | Purpose | Already in Project |
|---------|---------|---------|-------------------|
| flutter_riverpod | 3.x | State management | Yes |
| lucide_icons_flutter | latest | Icon library | Yes |
| url_launcher | latest | External URL opening | Yes |

### Supporting

No new libraries needed. Zero new deps (locked decision from v2.0 planning).

## Architecture Patterns

### Files to Modify

```
pro_orc/lib/
  data/services/quick_actions_service.dart    # Add openClaude() method
  features/shared/quick_actions.dart          # Remove Terminal from quick action list
  features/shared/project_context_menu.dart   # Add Terminal menu item
  features/code/code_project_card.dart        # Add Claude button widget
  features/research/research_project_card.dart # Add Claude button widget
```

### Pattern 1: Claude Button as Separate Widget (Not in Quick Action Row)

**What:** The Claude button should NOT be inside `buildQuickActionRow()`. It needs to be a visually distinct, larger widget positioned prominently on the card.

**When to use:** When an action needs visual differentiation from the compact icon-only quick actions.

**Example:**
```dart
// Claude button — separate from quick action row, visually prominent
Widget _buildClaudeButton(AppColors colors) {
  return SizedBox(
    height: 32,
    child: TextButton.icon(
      onPressed: () => ref.read(quickActionsProvider).openClaude(widget.project.path),
      icon: Icon(LucideIcons.terminal100, size: 16, color: colors.cyan),
      label: Text(
        'Claude',
        style: TextStyle(color: colors.cyan, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        backgroundColor: colors.cyan.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    ),
  );
}
```

### Pattern 2: openClaude() Service Method

**What:** A new method in `QuickActionsService` that launches `claude` in the project directory without a prompt.

**Example:**
```dart
/// Opens Terminal.app, cd's into the project directory, and starts Claude Code.
Future<void> openClaude(String projectPath) async {
  final script = _terminalScript('cd "$projectPath" && claude');
  await Process.run('osascript', ['-e', script], runInShell: true);
  await Process.run('open', ['-a', 'Terminal'], runInShell: true);
}
```

This follows the exact same pattern as `openRemSleep()` and `openClaudeWithPrompt()`.

### Pattern 3: Terminal in Context Menu

**What:** Add a 'Terminal' option to the existing right-click context menu.

**Example:**
```dart
// In project_context_menu.dart, add to items list:
PopupMenuItem(
  value: 'terminal',
  child: Text('Terminal'),
),

// In the .then() handler:
} else if (value == 'terminal') {
  QuickActionsService().openInTerminal(project.path);
}
```

Note: The context menu handler currently uses inline code. The `QuickActionsService` instance needs to be accessible -- either passed as parameter or instantiated inline (it's stateless, so instantiation is fine).

### Card Layout (Both Card Types)

**Current layout (bottom of card):**
```
[MemoryIndicator]
[Spacer]
[Terminal] [Finder] [GitHub] [Notion] [Memory]  <-- quick action row
```

**New layout:**
```
[MemoryIndicator]
[Spacer]
[Claude Button]                                  <-- prominent, separate
[Finder] [GitHub] [Notion] [Memory]              <-- reduced quick action row
```

The Claude button sits above the quick action row, full-width or left-aligned, with cyan background tint.

### Anti-Patterns to Avoid

- **Do NOT add Claude button inside `buildQuickActionRow()`**: It would be the same tiny 32x32 icon as Terminal -- violates CLB-02 requirement for visual prominence.
- **Do NOT remove Terminal entirely**: CLB-03 requires it remains accessible via context menu or secondary action.
- **Do NOT create a new provider for the Claude button**: Use existing `quickActionsProvider` -- the service is already a singleton.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Terminal launch | Custom Process.run for claude | `_terminalScript()` pattern in QuickActionsService | PATH issues on macOS GUI apps; osascript is proven |
| Icon rendering | Custom SVG for Claude | LucideIcons.terminal100 or LucideIcons.sparkles100 | Consistent with existing icon system |
| Button styling | Custom painted widget | TextButton.icon with AppColors.cyan | Theme-consistent, accessible |

## Common Pitfalls

### Pitfall 1: Forgetting Both Card Types
**What goes wrong:** Only updating CodeProjectCard and forgetting ResearchProjectCard.
**Why it happens:** Phase description says "project cards" but there are two separate card widgets.
**How to avoid:** Update both `code_project_card.dart` AND `research_project_card.dart`.
**Warning signs:** Research tab cards still show old Terminal button.

### Pitfall 2: Context Menu Needs QuickActionsService Access
**What goes wrong:** `showProjectContextMenu()` currently doesn't have access to `QuickActionsService`.
**Why it happens:** The function signature only takes `BuildContext`, `TapUpDetails`, `WidgetRef`, etc. -- no service instance.
**How to avoid:** Either pass `QuickActionsService` as a parameter, or read it from `ref.read(quickActionsProvider)` inside the handler (WidgetRef is already available).
**Warning signs:** Compile error when trying to call `openInTerminal` from context menu.

### Pitfall 3: Visual Consistency Between Tabs
**What goes wrong:** Claude button looks different on Code vs Research cards due to accent color differences.
**Why it happens:** Code tab uses cyan accent, Research tab uses fuchsia accent.
**How to avoid:** Claude button should ALWAYS use cyan (it represents Claude Code, not the tab). This is a locked decision: "Claude-Button ist visuell hervorgehoben (Cyan)".
**Warning signs:** Button appears in fuchsia on research cards.

### Pitfall 4: Card Height Changes
**What goes wrong:** Adding Claude button increases card content height, potentially breaking grid layout.
**Why it happens:** Cards use `Column` with `Spacer` -- adding another widget pushes content.
**How to avoid:** The Claude button replaces Terminal in the quick action row AND sits in a compact size. Net height change is minimal. Test both card types visually.

## Code Examples

### Existing Pattern: openRemSleep (Same Pattern to Follow)

```dart
// Source: pro_orc/lib/data/services/quick_actions_service.dart
Future<void> openRemSleep(String projectPath) async {
  final script = _terminalScript('cd "$projectPath" && claude /rem-sleep');
  await Process.run('osascript', ['-e', script], runInShell: true);
  await Process.run('open', ['-a', 'Terminal'], runInShell: true);
}
```

### Existing Pattern: Quick Action List Builder

```dart
// Source: pro_orc/lib/features/shared/quick_actions.dart
List<QuickAction> buildProjectQuickActions(
  ProjectModel project,
  QuickActionsService qa,
) {
  return [
    QuickAction(
      icon: LucideIcons.terminal100,  // <-- REMOVE this entry
      tooltip: 'Terminal',
      onPressed: () => qa.openInTerminal(project.path),
    ),
    // ... rest stays
  ];
}
```

### Existing Pattern: Context Menu Item

```dart
// Source: pro_orc/lib/features/shared/project_context_menu.dart
PopupMenuItem(
  value: 'toggle_hidden',
  child: Text(isHidden ? 'Oeffentlich' : 'Privat'),
),
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | `pro_orc/pubspec.yaml` (dev_dependencies) |
| Quick run command | `cd pro_orc && flutter test test/data/` |
| Full suite command | `cd pro_orc && flutter test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLB-01 | `openClaude()` launches terminal with claude command | unit | `flutter test test/data/services/quick_actions_service_test.dart -x` | No -- Wave 0 |
| CLB-02 | Claude button is visually prominent (cyan, larger) | manual-only | Visual inspection | N/A |
| CLB-03 | Terminal removed from quick action row, present in context menu | unit | `flutter test test/data/services/quick_actions_service_test.dart -x` | No -- Wave 0 |

### Sampling Rate

- **Per task commit:** `cd pro_orc && flutter test test/data/`
- **Per wave merge:** `cd pro_orc && flutter test && flutter analyze`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/data/services/quick_actions_service_test.dart` -- covers CLB-01 (openClaude method generates correct osascript)
- Note: Widget tests for CLB-02/CLB-03 are optional -- these are UI layout changes best verified visually. The service method is the testable unit.

## Open Questions

1. **Claude button icon choice**
   - What we know: LucideIcons has `terminal100`, `sparkles100`, `bot100`, `messageSquare100` -- all could represent Claude
   - What's unclear: Which icon best communicates "Start Claude Code" vs generic terminal
   - Recommendation: Use `LucideIcons.sparkles100` or `LucideIcons.terminal100` with "Claude" text label. The text label disambiguates regardless of icon choice. Planner decides.

2. **Button position on card**
   - What we know: Must be "prominent" and "primary action" per CLB-02
   - What's unclear: Above quick action row vs. replacing quick action row entirely
   - Recommendation: Place Claude button directly above the quick action row, left-aligned. Quick action row shrinks (minus Terminal). This gives visual hierarchy: primary action (Claude) above secondary actions (Finder, GitHub, etc.).

## Sources

### Primary (HIGH confidence)
- Project source code: `quick_actions_service.dart`, `quick_actions.dart`, `code_project_card.dart`, `research_project_card.dart`, `project_context_menu.dart`
- CLAUDE.md project conventions
- ROADMAP.md Phase 22 specification
- STATE.md locked decisions ("Claude-Button via osascript + Terminal.app")

### Secondary (MEDIUM confidence)
- MEMORY.md: "Claude-Button: Trivial (~15 LOC), gleicher osascript Pattern wie openInTerminal/openRemSleep"

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new deps, all existing infrastructure
- Architecture: HIGH -- follows established patterns exactly (openRemSleep, quick actions, context menu)
- Pitfalls: HIGH -- known from direct code inspection, no speculation

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable -- no external dependencies changing)
