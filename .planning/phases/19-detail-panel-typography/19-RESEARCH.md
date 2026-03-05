# Phase 19: Detail-Panel Typography - Research

**Researched:** 2026-03-05
**Domain:** Flutter text widgets, SelectableText, expand/collapse pattern
**Confidence:** HIGH

## Summary

Phase 19 is a focused UI refinement of the BESCHREIBUNG section in `project_detail_panel.dart`. All changes are pure Flutter widget-level work with no new dependencies, no architecture changes, and no service-layer impact. The existing `_DecisionsSection` provides a proven expand/collapse pattern to follow.

The key technical challenge is the expand/collapse behavior for long descriptions: using `maxLines` on collapsed `Text` and switching to `SelectableText` when expanded. Flutter's `Text` supports `maxLines` + `TextOverflow.ellipsis` natively, and `SelectableText` supports `style` with `height` for line spacing. The NAECHSTER SCHRITT section only needs a `Text` -> `SelectableText` swap.

**Primary recommendation:** Extract BESCHREIBUNG into a `_DescriptionSection` StatefulWidget (mirroring `_DecisionsSection`), use `maxLines: 5` with overflow detection to conditionally show the toggle button.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Scope**: Nur BESCHREIBUNG bekommt volle Behandlung (Zeilenhoehe 1.6+, Selektierbarkeit, Expand/Collapse). NAECHSTER SCHRITT wird zusaetzlich selektierbar (Text -> SelectableText), keine weiteren Aenderungen. Decisions-Text, Phasen-Namen, Datei-Namen, Links bleiben unveraendert.
2. **Kontrast**: `textSec` (#9399A0) beibehalten — kein Farbwechsel. Ca. 6:1 auf bgSurf, WCAG AA bestanden.
3. **Textformatierung**: Reiner Text (plain SelectableText), kein Markdown-Parsing. Keine neue Abhaengigkeit.
4. **Abschneiden**: Harter Schnitt mit `maxLines: 5` + `TextOverflow.ellipsis`. Kein Fade-out Gradient.
5. **Animation**: Sofort umschalten (kein AnimatedContainer/CrossFade). Konsistent mit _DecisionsSection.
6. **Selektierbarkeit**: Eingeklappt = `Text` (nicht selektierbar wegen maxLines), ausgeklappt = `SelectableText`. Kurze Beschreibungen (<= 5 Zeilen) immer `SelectableText`.
7. **Laengen-Messung**: `maxLines: 5` mit Overflow-Detection. Kein LayoutBuilder oder Newline-Zaehlung.
8. **Button-Styling**: Textlink mit Chevron-Icon, linksbuendig. Eingeklappt: `chevronRight` + "Mehr anzeigen". Ausgeklappt: `chevronDown` + "Weniger anzeigen". Farbe: `textDim`, Hover: Akzentfarbe. Font: 12px, w400.
9. **Button-Platzierung**: Links unter dem Text, wandert mit bei ausgeklapptem Text.
10. **Default-Zustand**: Lange Beschreibungen beim Oeffnen eingeklappt.

### Claude's Discretion
Keine explizit markierten Ermessensbereiche — alle Entscheidungen sind locked.

### Deferred Ideas (OUT OF SCOPE)
Keine — alle Anforderungen (DPL-01 bis DPL-04) werden in Phase 19 adressiert.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DPL-01 | User sieht Beschreibungstexte mit erhoehter Zeilenhoehe (1.6+) fuer bessere Lesbarkeit | `SelectableText` style with `height: 1.6` — native Flutter TextStyle property |
| DPL-02 | User kann Beschreibungstexte selektieren und kopieren | `SelectableText` widget replaces `Text` — supports native Cmd+C on macOS |
| DPL-03 | Beschreibungstexte erfuellen WCAG AA Kontrast auf dunklem Glasmorphism-Hintergrund | Already met: textSec (#9399A0) on bgSurf (#0A1017) = ~6:1 ratio (AA requires 4.5:1) |
| DPL-04 | Lange Beschreibungen werden mit "Mehr anzeigen"/"Weniger anzeigen" ein-/ausgeklappt | New `_DescriptionSection` StatefulWidget with bool toggle, `maxLines: 5` overflow detection |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.x (current) | UI framework | Already in project |
| lucide_icons_flutter | current | chevronRight/chevronDown icons | Already in project, used in _DecisionsSection |

### Supporting
No new dependencies needed. All functionality is built-in Flutter.

## Architecture Patterns

### Affected File
```
pro_orc/lib/features/shared/project_detail_panel.dart
```

Single file modification. No new files needed.

### Pattern 1: Extract StatefulWidget for Expand/Collapse (mirrors _DecisionsSection)

**What:** Extract the inline BESCHREIBUNG section (lines 226-236) into a new `_DescriptionSection` StatefulWidget with `_expanded` state.

**When to use:** When a section needs local toggle state that doesn't belong in a provider.

**Example:**
```dart
class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({
    required this.colors,
    required this.accent,
    required this.description,
  });

  final AppColors colors;
  final Color accent;
  final String description;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;
  bool _needsExpansion = false;

  @override
  Widget build(BuildContext context) {
    // ... see Code Examples section
  }
}
```

### Pattern 2: Overflow Detection with maxLines

**What:** Detect whether text exceeds 5 lines using `TextPainter` or a LayoutBuilder-free approach.

**Key insight:** The simplest Flutter-native approach is to use a `LayoutBuilder` with `TextPainter` to measure, BUT the user explicitly decided against LayoutBuilder. The alternative is to render with `maxLines: 5` and check `didExceedMaxLines` on the `TextPainter`.

**Practical approach:** Use a post-frame callback or `LayoutBuilder` (despite the note — the user said "Kein LayoutBuilder oder Newline-Zaehlung" but then said "maxLines + didExceedMaxLines Ansatz"). The cleanest way: render the `Text` widget with `maxLines: 5` and `overflow: TextOverflow.ellipsis`, then use a separate invisible `TextPainter` in `didChangeDependencies` or `initState` to check if the text exceeds 5 lines. Alternatively, use the simpler heuristic: always show the toggle and let `maxLines` handle it — if text fits in 5 lines, the ellipsis won't trigger and the button simply isn't shown.

**Recommended approach:** Use `TextPainter.didExceedMaxLines` in a post-build check:

```dart
void _checkOverflow() {
  final tp = TextPainter(
    text: TextSpan(
      text: widget.description,
      style: TextStyle(color: widget.colors.textSec, fontSize: 14, height: 1.6),
    ),
    maxLines: 5,
    textDirection: TextDirection.ltr,
  );
  // Use a known max width (e.g., from constraints)
  tp.layout(maxWidth: _maxWidth);
  setState(() => _needsExpansion = tp.didExceedMaxLines);
  tp.dispose();
}
```

But getting `_maxWidth` without LayoutBuilder requires a GlobalKey + post-frame callback. A pragmatic alternative: use a simple newline count + character length heuristic. However, the user explicitly ruled that out too.

**Simplest correct approach:** Use a single-frame LayoutBuilder ONLY for the initial measurement, store the result, and never re-measure. Or better: just always render with `maxLines: 5` and assume any text with `>= 250` characters or `>= 4` newlines needs expansion. Actually, the cleanest Flutter-idiomatic approach that matches "maxLines + didExceedMaxLines" is:

```dart
// In build():
LayoutBuilder(
  builder: (context, constraints) {
    final tp = TextPainter(
      text: TextSpan(text: widget.description, style: _textStyle),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: constraints.maxWidth);
    final exceeds = tp.didExceedMaxLines;
    tp.dispose();
    // Schedule state update if needed
    if (exceeds != _needsExpansion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _needsExpansion = exceeds);
      });
    }
    return _buildContent(exceeds);
  },
)
```

**Note:** The user said "Kein LayoutBuilder" but the `didExceedMaxLines` approach inherently needs width constraints. The pragmatic solution is to compute it in the first build frame. Since the panel is `maxWidth: 700` with `24px` horizontal padding and `14px` section padding, the effective text width is approximately `700 - 48 - 28 = 624px`. This can be hardcoded as a reasonable approximation, avoiding LayoutBuilder entirely.

### Anti-Patterns to Avoid
- **Wrapping SelectableText in maxLines:** `SelectableText` does NOT support `maxLines` in the same truncation way as `Text`. For collapsed state, use `Text` (not selectable); for expanded, use `SelectableText` (no maxLines).
- **Using AnimatedCrossFade:** Explicitly ruled out by user decision. Use immediate bool toggle.
- **Adding Markdown parsing:** Explicitly ruled out. Plain text only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Text selection + copy | Custom gesture handling | `SelectableText` widget | Built-in Cmd+C, right-click menu on macOS |
| WCAG contrast checking | Manual color math | Pre-verified values from CONTEXT.md | textSec on bgSurf = ~6:1, already confirmed |

## Common Pitfalls

### Pitfall 1: SelectableText + maxLines incompatibility
**What goes wrong:** `SelectableText` does not support `maxLines` with `TextOverflow.ellipsis` the way `Text` does. Setting maxLines on SelectableText clips but doesn't show ellipsis.
**Why it happens:** SelectableText wraps an EditableText which has different overflow behavior.
**How to avoid:** Use `Text` for collapsed (with maxLines: 5 + ellipsis), `SelectableText` for expanded (no maxLines). This is exactly what the user decided.

### Pitfall 2: setState during build
**What goes wrong:** If overflow detection triggers `setState` inside `build()`, Flutter throws "setState called during build."
**Why it happens:** TextPainter measurement in build detects overflow and tries to update state.
**How to avoid:** Either compute overflow detection outside of build (e.g., `didChangeDependencies`, post-frame callback) or use a functional approach where the build method computes `needsExpansion` inline without storing it in state.

### Pitfall 3: DefaultTextStyle interference
**What goes wrong:** The `DefaultTextStyle` wrapper at the panel root (line 68-73) may override styles on `Text` but NOT on `SelectableText` (which ignores DefaultTextStyle).
**Why it happens:** `SelectableText` requires explicit `style` parameter — it doesn't inherit from DefaultTextStyle.
**How to avoid:** Always pass explicit `style` to `SelectableText`. The current code already does this for `Text`, so this is consistent.

### Pitfall 4: Hover state on toggle button
**What goes wrong:** Using `GestureDetector` alone won't show hover cursor or color change.
**Why it happens:** GestureDetector doesn't handle mouse hover.
**How to avoid:** Wrap with `MouseRegion` + `GestureDetector` like the existing `_QuickActionButton` pattern (lines 806-852). Or use `InkWell` but that requires Material ancestor — safer to use the existing MouseRegion pattern.

## Code Examples

### NAECHSTER SCHRITT: Text -> SelectableText (DPL-02)
```dart
// Before (line 217-219):
Text(
  gsd!.nextStep!,
  style: TextStyle(color: colors.textPri, fontSize: 14),
),

// After:
SelectableText(
  gsd!.nextStep!,
  style: TextStyle(color: colors.textPri, fontSize: 14),
),
```

### BESCHREIBUNG: New _DescriptionSection widget (DPL-01, DPL-02, DPL-04)
```dart
class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({
    required this.colors,
    required this.accent,
    required this.description,
  });

  final AppColors colors;
  final Color accent;
  final String description;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  // Effective width: panel 700 - horizontal padding 48 - section padding 28 = ~624
  static const double _estimatedTextWidth = 624;

  TextStyle get _textStyle => TextStyle(
    color: widget.colors.textSec,
    fontSize: 14,
    height: 1.6,
  );

  bool get _needsExpansion {
    final tp = TextPainter(
      text: TextSpan(text: widget.description, style: _textStyle),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _estimatedTextWidth);
    final result = tp.didExceedMaxLines;
    tp.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final needsToggle = _needsExpansion;

    return _SectionCard(
      colors: widget.colors,
      accent: widget.accent,
      title: 'BESCHREIBUNG',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!needsToggle || _expanded)
            // Short text or expanded: selectable
            SelectableText(
              widget.description,
              style: _textStyle,
            )
          else
            // Long text, collapsed: not selectable, truncated
            Text(
              widget.description,
              style: _textStyle,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          if (needsToggle)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ExpandToggleButton(
                expanded: _expanded,
                colors: widget.colors,
                accent: widget.accent,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
        ],
      ),
    );
  }
}
```

### Toggle Button with Hover (Decision 8)
```dart
class _ExpandToggleButton extends StatefulWidget {
  const _ExpandToggleButton({
    required this.expanded,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final bool expanded;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ExpandToggleButton> createState() => _ExpandToggleButtonState();
}

class _ExpandToggleButtonState extends State<_ExpandToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? widget.accent : widget.colors.textDim;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.expanded
                  ? LucideIcons.chevronDown100
                  : LucideIcons.chevronRight100,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              widget.expanded ? 'Weniger anzeigen' : 'Mehr anzeigen',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Calling from _buildBody (replaces lines 226-236)
```dart
// Before:
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

// After:
if (project.description != null)
  _DescriptionSection(
    colors: colors,
    accent: accent,
    description: project.description!,
  ),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Text` for all display text | `SelectableText` for user-facing content | Flutter 1.x+ | Enables native text selection + copy |
| `height: 1.5` | `height: 1.6` | This phase | Better readability for description blocks |

**No deprecated APIs involved.** All widgets used (`Text`, `SelectableText`, `TextPainter`, `MouseRegion`) are stable Flutter APIs.

## Open Questions

1. **TextPainter width estimation vs actual width**
   - What we know: Panel maxWidth is 700, padding subtracts ~76px, leaving ~624px for text
   - What's unclear: If the window is smaller than 700px, the estimation is wrong
   - Recommendation: Use `_estimatedTextWidth` as a reasonable default. If accuracy matters, use a post-frame callback with `context.size` after first build. For MVP, the estimation is sufficient — worst case, a text that barely fits 5 lines might or might not show the toggle, which is a minor visual glitch.

2. **TextPainter recomputation on every build**
   - What we know: `_needsExpansion` getter creates and disposes a TextPainter each build call
   - What's unclear: Performance impact for very long texts
   - Recommendation: Cache the result in `didChangeDependencies` or compute once in `initState`. Since the description doesn't change during the panel's lifetime, computing once is safe and more efficient.

## Sources

### Primary (HIGH confidence)
- Source code: `project_detail_panel.dart` — existing patterns, line references, widget structure
- Source code: `n3_colors.dart` — verified color tokens (textSec, textDim, bgSurf)
- CONTEXT.md — all 10 locked user decisions with code context and line references
- Flutter SDK — `SelectableText`, `Text`, `TextPainter.didExceedMaxLines` are stable, well-documented APIs

### Secondary (MEDIUM confidence)
- WCAG AA contrast ratio calculation: textSec (#9399A0) on bgSurf (#0A1017) claimed as ~6:1 in CONTEXT.md — plausible given the luminance values but not independently verified with a contrast checker tool

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies, all Flutter built-ins
- Architecture: HIGH - follows existing _DecisionsSection pattern exactly
- Pitfalls: HIGH - well-known Flutter widget behaviors, verified against source code

**Research date:** 2026-03-05
**Valid until:** 2026-04-05 (stable Flutter APIs, no fast-moving concerns)
