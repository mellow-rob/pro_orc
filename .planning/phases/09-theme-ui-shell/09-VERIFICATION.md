---
phase: 09-theme-ui-shell
verified: 2026-02-20T00:00:00Z
status: human_needed
score: 7/7 automated must-haves verified
human_verification:
  - test: "Visual appearance — orbs, glassmorphism, colors"
    expected: "Two cyan and one fuchsia translucent orb visible, slowly drifting. No white halo on GlassCard edges. No border on cards or shell. Soft off-white text (#E0E5EB), not pure white."
    why_human: "Animation behavior, blur quality, and color fidelity cannot be verified from static code inspection."
  - test: "Tab navigation — three tabs switch correctly"
    expected: "Clicking Code / Research / Claude Tools in the left NavigationRail highlights the selected tab with a cyan indicator and shows that tab's GlassCard placeholder. State preserved across switches (IndexedStack)."
    why_human: "Interactive behavior at runtime; IndexedStack state preservation requires user interaction to observe."
  - test: "Window glow aesthetic"
    expected: "GlowBorderShell renders a subtle cyan/fuchsia outer shadow glow around the window — no visible border line, only soft shadow."
    why_human: "BoxShadow rendering quality and absence of unwanted border artifacts require visual inspection."
---

# Phase 9: Theme + UI Shell Verification Report

**Phase Goal:** The app renders the n3urala1 dark theme with correct cyan/fuchsia colors, glassmorphism card backgrounds, atmospheric orbs, and a three-tab navigation bar — all before any card content is wired.
**Verified:** 2026-02-20
**Status:** human_needed — all automated checks pass; 3 items need human visual confirmation
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | All n3urala1 color tokens exist as typed const Color values accessible via `Theme.of(context).extension<AppColors>()` | VERIFIED | `n3_colors.dart` — `class AppColors extends ThemeExtension<AppColors>` with `static const dark` instance containing all 16 sRGB tokens (bgBase, bgSurf, bgElev, bgCard, cyanHi, cyan, cyanLo, cyanOrb, fuchHi, fuch, fuchLo, fuchOrb, textPri, textSec, textDim, textDis) |
| 2 | ThemeData uses AppColors extension and configures ColorScheme, NavigationRailThemeData, and scaffoldBackgroundColor | VERIFIED | `app_theme.dart` — `buildAppTheme()` sets `scaffoldBackgroundColor: colors.bgBase`, full `ColorScheme.dark(...)`, `NavigationRailThemeData(...)`, and `extensions: const [AppColors.dark]` |
| 3 | GlowBorderShell uses AppColors tokens, has no border, and uses `withValues(alpha:)` instead of deprecated `withOpacity()` | VERIFIED | `glow_border_shell.dart` — reads `Theme.of(context).extension<AppColors>()!`, no `Border.all`, zero `withOpacity` calls, BoxShadow uses `colors.cyan.withValues(alpha: 0.15)` and `colors.fuch.withValues(alpha: 0.08)` |
| 4 | Three tabs (Code, Research, Claude Tools) are visible in a left sidebar NavigationRail and switching tabs shows the correct container | VERIFIED (code) | `shell_screen.dart` — `NavigationRail` with 3 `NavigationRailDestination` entries, `IndexedStack(index: _selectedIndex)` holding `CodeTab()`, `ResearchTab()`, `ClaudeToolsTab()`, `setState(() => _selectedIndex = i)` on selection |
| 5 | Background renders animated atmospheric orbs (cyan and fuchsia) drifting slowly | VERIFIED (code) | `orb_background.dart` — `StatefulWidget` with `TickerProviderStateMixin`, three `AnimationController` instances (18s/23s/28s, `repeat(reverse: true)`), `_OrbPainter` draws 3 radial gradient orbs using `cyanOrb` and `fuchOrb` tokens; placed as `Positioned.fill` in a `Stack` behind the `Scaffold` |
| 6 | GlassCard shows correct blur with no white halo artifact and no border | VERIFIED (code) | `glass_card.dart` — `ClipRRect > BackdropFilter(blendMode: BlendMode.src, filter: ImageFilter.blur)` with no `Border` in `BoxDecoration`; `BlendMode.src` is the established Flutter fix for white halo on dark backgrounds |
| 7 | All visual elements use AppColors tokens from the ThemeExtension (no hardcoded hex values in new UI files) | VERIFIED | Every new widget (`orb_background.dart`, `glass_card.dart`, `code_tab.dart`, `research_tab.dart`, `claude_tools_tab.dart`, `shell_screen.dart`) calls `Theme.of(context).extension<AppColors>()!` for all color values; only `n3_colors.dart` itself contains hex literals (by design) |

**Score:** 7/7 automated truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pro_orc/lib/theme/n3_colors.dart` | AppColors ThemeExtension with all 16 sRGB tokens | VERIFIED | 139 lines, `class AppColors extends ThemeExtension<AppColors>`, `static const dark`, full `copyWith()` and `lerp()` |
| `pro_orc/lib/theme/app_theme.dart` | ThemeData factory with AppColors extension registered | VERIFIED | 37 lines, `ThemeData buildAppTheme()`, `extensions: const [AppColors.dark]` |
| `pro_orc/lib/main.dart` | App using `buildAppTheme()` | VERIFIED | `theme: buildAppTheme()` at line 58 |
| `pro_orc/lib/features/shell/glow_border_shell.dart` | AppColors tokens, no border, no `withOpacity` | VERIFIED | 41 lines, reads AppColors via ThemeExtension, no `Border`, no `withOpacity` |
| `pro_orc/lib/features/shell/orb_background.dart` | Animated orb background with CustomPainter | VERIFIED | 138 lines, `class OrbBackground` StatefulWidget, `_OrbPainter extends CustomPainter`, 3 controllers, `RepaintBoundary` |
| `pro_orc/lib/features/shell/glass_card.dart` | Glassmorphism card with BackdropFilter | VERIFIED | 46 lines, `class GlassCard`, `BackdropFilter(blendMode: BlendMode.src)`, no border |
| `pro_orc/lib/features/shell/shell_screen.dart` | Shell with NavigationRail + IndexedStack + OrbBackground | VERIFIED | `NavigationRail`, `IndexedStack`, `OrbBackground` as `Positioned.fill`, `Scaffold.backgroundColor: Colors.transparent` |
| `pro_orc/lib/features/code/code_tab.dart` | Code tab placeholder with GlassCard | VERIFIED | 25 lines, `class CodeTab`, centered `GlassCard` with `Text('Code')` using `colors.textPri` |
| `pro_orc/lib/features/research/research_tab.dart` | Research tab placeholder with GlassCard | VERIFIED | 25 lines, `class ResearchTab`, centered `GlassCard` with `Text('Research')` |
| `pro_orc/lib/features/claude_tools/claude_tools_tab.dart` | Claude Tools tab placeholder with GlassCard | VERIFIED | 25 lines, `class ClaudeToolsTab`, centered `GlassCard` with `Text('Claude Tools')` |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `main.dart` | `app_theme.dart` | `theme: buildAppTheme()` | WIRED | Line 58: `theme: buildAppTheme()` — import confirmed at line 10 |
| `app_theme.dart` | `n3_colors.dart` | `extensions: const [AppColors.dark]` | WIRED | Line 35: `extensions: const [AppColors.dark]` — import at line 2 |
| `shell_screen.dart` | `orb_background.dart` | `OrbBackground` as `Positioned.fill` in Stack | WIRED | Line 95: `const Positioned.fill(child: OrbBackground())` — import confirmed |
| `shell_screen.dart` | `code_tab.dart` | `IndexedStack` children list | WIRED | Line 136: `CodeTab()` in `IndexedStack` children — import confirmed |
| `glass_card.dart` | `n3_colors.dart` | `Theme.of(context).extension<AppColors>()` | WIRED | Line 29: `Theme.of(context).extension<AppColors>()!` — import at line 4 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| UI-04 | 09-02-PLAN.md | Tab-Navigation: Code / Research / Claude Tools | SATISFIED | `shell_screen.dart` NavigationRail with 3 destinations + IndexedStack; all three tab widgets exist and are wired |
| UI-05 | 09-01-PLAN.md, 09-02-PLAN.md | n3urala1 Dark Theme (OKLCH-to-sRGB, Cyan/Fuchsia, Glassmorphism) | SATISFIED (code) / NEEDS HUMAN (visual) | `n3_colors.dart` has all 16 OKLCH-converted tokens; `app_theme.dart` registers them; `glass_card.dart` provides glassmorphism; visual quality requires human confirmation |

**Orphaned requirements:** None. REQUIREMENTS.md maps only UI-04 and UI-05 to Phase 9. Both are claimed by plans and have implementation evidence.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `pro_orc/lib/features/shell/launch_dialog.dart` | 12 | `withOpacity(0.2)` — deprecated API | Info | Pre-existing, not introduced by Phase 9. Logged in `deferred-items.md`. Does not affect phase goal. Build succeeds. |

No blockers or warnings introduced by Phase 9 files. The `launch_dialog.dart` deprecation is pre-existing and was explicitly deferred per phase convention.

---

## Human Verification Required

### 1. Orb Animation Appearance

**Test:** Run `flutter run -d macos` from `pro_orc/`. Observe the window background.
**Expected:** Two translucent cyan orbs and one fuchsia orb visible as soft colored fog, slowly drifting. Orbs should bleed behind the NavigationRail sidebar and all tab content (not clipped to the content area).
**Why human:** Animation behavior, translucency quality, and orb color fidelity require visual inspection at runtime. Static code confirms the mechanism but not the perceptual result.

### 2. Three-Tab Navigation Interaction

**Test:** Click each of the three icons in the left NavigationRail (Code, Research, Claude Tools). Observe icon/label highlighting and content area changes.
**Expected:** Selected tab icon/label becomes cyan. Content area shows the correct GlassCard placeholder for that tab. State preserved when switching back.
**Why human:** Tab switching and state preservation (IndexedStack) are interactive runtime behaviors. The `setState()` call is present in code, but correctness requires a click.

### 3. GlassCard Visual Quality — No White Halo, No Border

**Test:** In any tab, observe the GlassCard containing the placeholder text.
**Expected:** Card has a frosted-glass appearance with visible backdrop blur. No white or bright halo around card edges. No visible border line. The background orbs should be faintly visible through the card.
**Why human:** `BlendMode.src` on BackdropFilter is the established mitigation for the white halo artifact, but whether it fully suppresses it on the user's macOS version and display requires visual confirmation. Border absence is code-verified, but halo suppression is not.

### 4. Window Glow Aesthetic

**Test:** Observe the window outer edge.
**Expected:** Subtle cyan/fuchsia outer glow from GlowBorderShell BoxShadow — visible as soft colored shadow, not a solid border line.
**Why human:** BoxShadow rendering at the window edge depends on macOS compositor behavior and window manager integration. GlowBorderShell code is correct, but shadow visibility requires runtime check.

---

## Commits Verified

All commits documented in SUMMARY files exist in the repository:

| Hash | Message |
|------|---------|
| `47e8bdf` | feat(09-01): create AppColors ThemeExtension and buildAppTheme factory |
| `8b6f51b` | feat(09-01): update GlowBorderShell to use AppColors, remove border, fix withOpacity |
| `baf4447` | feat(09-02): add OrbBackground and GlassCard widgets |
| `4eb520c` | feat(09-02): wire NavigationRail, OrbBackground, and tab placeholders into ShellScreen |

---

## Summary

Phase 9 has strong automated verification coverage. All 10 required files exist, are substantive (not stubs), and are correctly wired. The entire token chain — from `n3_colors.dart` through `app_theme.dart` to `buildAppTheme()` in `main.dart` — is intact. Every widget in the new visual shell reads colors from the ThemeExtension rather than hardcoded hex values. The three-tab navigation structure is fully wired. No deprecated `withOpacity` calls were introduced by Phase 9 (the pre-existing one in `launch_dialog.dart` is deferred and documented).

The phase goal is structurally achieved. Human visual verification is the remaining gate, consistent with the plan's own checkpoint task (Task 3 in 09-02-PLAN.md was a blocking human-verify checkpoint). The SUMMARY documents that human approval was given, but this verifier cannot independently confirm visual quality — that remains a human responsibility.

---

_Verified: 2026-02-20_
_Verifier: Claude (gsd-verifier)_
