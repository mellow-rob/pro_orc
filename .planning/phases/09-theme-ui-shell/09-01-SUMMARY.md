---
phase: 09-theme-ui-shell
plan: "01"
subsystem: theme
tags: [theme, colors, ThemeExtension, tokens, glassmorphism]
dependency_graph:
  requires: []
  provides: [AppColors ThemeExtension, buildAppTheme factory]
  affects: [GlowBorderShell, main.dart, all future UI widgets]
tech_stack:
  added: []
  patterns: [ThemeExtension<T>, ColorScheme.dark, NavigationRailThemeData, withValues(alpha:)]
key_files:
  created:
    - pro_orc/lib/theme/n3_colors.dart
    - pro_orc/lib/theme/app_theme.dart
  modified:
    - pro_orc/lib/main.dart
    - pro_orc/lib/features/shell/glow_border_shell.dart
decisions:
  - "AppColors uses static const dark instance — avoids runtime allocation, const-propagates into ThemeData.extensions"
  - "No border on GlowBorderShell (locked decision) — border removed, only glow BoxShadow remains"
  - "withValues(alpha:) replaces withOpacity() throughout touched files — Flutter 3.38+ compliance"
metrics:
  duration: "~3 min"
  completed: "2026-02-20"
  tasks: 2
  files: 4
---

# Phase 9 Plan 01: Theme Token System Summary

AppColors ThemeExtension with 16 pre-computed n3urala1 sRGB tokens, ThemeData factory, and GlowBorderShell cleanup using typed color access and no deprecated APIs.

## What Was Built

**n3_colors.dart** — `AppColors extends ThemeExtension<AppColors>` with all 16 color tokens as typed `final Color` fields. Pre-computed OKLCH-to-sRGB hex values. `static const dark` instance. Full `copyWith()` and `lerp()` implementations.

**app_theme.dart** — `buildAppTheme()` factory returning `ThemeData.dark().copyWith(...)` with:
- `scaffoldBackgroundColor: colors.bgBase`
- `colorScheme: ColorScheme.dark(surface, primary, secondary, onSurface, onPrimary)`
- `NavigationRailThemeData` with transparent background, indicator, selected/unselected styles
- `extensions: const [AppColors.dark]`

**main.dart** — Replaced inline `ThemeData.dark().copyWith(scaffoldBackgroundColor: ...)` with `theme: buildAppTheme()`.

**glow_border_shell.dart** — Rewrote to:
- Read `Theme.of(context).extension<AppColors>()!` for typed token access
- Remove `Border.all(...)` entirely (locked: no border on shells/cards)
- Use `withValues(alpha:)` exclusively (no `withOpacity` calls)
- Keep `ClipRRect` structure for Plan 02 orb clipping

## Commits

| Task | Hash | Message |
|------|------|---------|
| 1 | 47e8bdf | feat(09-01): create AppColors ThemeExtension and buildAppTheme factory |
| 2 | 8b6f51b | feat(09-01): update GlowBorderShell to use AppColors, remove border, fix withOpacity |

## Deviations from Plan

### Out-of-scope discovery (not fixed)

**launch_dialog.dart:12** — Pre-existing `withOpacity(0.2)` deprecation warning found during full `lib/` analyze. Not caused by this plan's changes. Logged to `deferred-items.md`. Recommend fixing in plan 09-02 or 09-03.

## Verification

- `flutter analyze lib/theme/ lib/main.dart lib/features/shell/glow_border_shell.dart` — No issues
- `flutter build macos --debug` — Built successfully
- No `withOpacity` calls in any file touched by this plan
- No `Border.all` in glow_border_shell.dart
- `AppColors.dark` contains all 16 sRGB tokens
- `ThemeExtension` subclass confirmed in `grep -r 'ThemeExtension' lib/theme/`

## Self-Check: PASSED

Files verified present:
- pro_orc/lib/theme/n3_colors.dart — FOUND
- pro_orc/lib/theme/app_theme.dart — FOUND
- pro_orc/lib/main.dart (updated) — FOUND
- pro_orc/lib/features/shell/glow_border_shell.dart (updated) — FOUND

Commits verified:
- 47e8bdf — FOUND
- 8b6f51b — FOUND
