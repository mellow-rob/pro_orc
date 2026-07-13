import 'package:flutter/material.dart';

/// n3urala1 design token color system.
///
/// All values are pre-computed sRGB hex conversions from the OKLCH design spec.
/// Access via: `Theme.of(context).extension<AppColors>()!`
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgBase,
    required this.bgSurf,
    required this.bgElev,
    required this.bgCard,
    required this.cyanHi,
    required this.cyan,
    required this.cyanLo,
    required this.cyanOrb,
    required this.fuchHi,
    required this.fuch,
    required this.fuchLo,
    required this.fuchOrb,
    required this.textPri,
    required this.textSec,
    required this.textDim,
    required this.textDis,
    required this.amberHi,
    required this.amber,
    required this.amberLo,
    required this.emeraldHi,
    required this.emerald,
    required this.emeraldLo,
    required this.violetHi,
    required this.violet,
    required this.violetLo,
  });

  // Background layers
  final Color bgBase; // oklch(0.065 0.015 260)
  final Color bgSurf; // oklch(0.17  0.018 255)
  final Color bgElev; // oklch(0.20  0.018 255)
  final Color bgCard; // oklch(0.22  0.016 255)

  // Cyan (PRIMARY)
  final Color cyanHi; // oklch(0.80 0.18 200)
  final Color cyan; // oklch(0.74 0.20 200)
  final Color cyanLo; // oklch(0.60 0.20 200)
  final Color cyanOrb; // oklch(0.52 0.22 200)

  // Fuchsia (SECONDARY)
  final Color fuchHi; // oklch(0.72 0.28 328)
  final Color fuch; // oklch(0.62 0.28 328)
  final Color fuchLo; // oklch(0.52 0.26 328)
  final Color fuchOrb; // oklch(0.48 0.28 328)

  // Text (gedaempft — not pure white)
  final Color textPri; // oklch(0.92 0.01  255)
  final Color textSec; // oklch(0.68 0.012 255)
  final Color textDim; // oklch(0.50 0.010 255)
  final Color textDis; // oklch(0.38 0.008 255)

  // Amber (Skills accent)
  final Color amberHi; // oklch(0.85 0.17 85) bright
  final Color amber; // oklch(0.78 0.17 85) mid
  final Color amberLo; // oklch(0.65 0.15 85) dim

  // Emerald (Plugins accent)
  final Color emeraldHi; // oklch(0.80 0.17 160) bright
  final Color emerald; // oklch(0.72 0.19 155) mid
  final Color emeraldLo; // oklch(0.60 0.17 155) dim

  // Violet (MCP accent)
  final Color violetHi; // oklch(0.75 0.20 290) bright
  final Color violet; // oklch(0.68 0.24 290) mid
  final Color violetLo; // oklch(0.55 0.22 290) dim

  /// Canonical dark theme instance with all 16 pre-computed sRGB tokens.
  ///
  /// Backgrounds are lifted slightly above pure near-black (v2.2 "heller"
  /// refresh) for a friendlier feel while keeping dark mode as the default.
  static const AppColors dark = AppColors(
    // Background layers
    bgBase: Color(0xFF0E0E14),
    bgSurf: Color(0xFF12181F),
    bgElev: Color(0xFF171D26),
    bgCard: Color(0xFF1C222B),

    // Cyan (PRIMARY)
    cyanHi: Color(0xFF00DEEB),
    cyan: Color(0xFF00CDDC),
    cyanLo: Color(0xFF009FAF),
    cyanOrb: Color(0xFF00879A),

    // Fuchsia (SECONDARY)
    fuchHi: Color(0xFFFA48FA),
    fuch: Color(0xFFD710D8),
    fuchLo: Color(0xFFAF00B1),
    fuchOrb: Color(0xFFA600A9),

    // Text
    textPri: Color(0xFFE0E5EB),
    textSec: Color(0xFF9399A0),
    textDim: Color(0xFF5F6469),
    textDis: Color(0xFF404347),

    // Amber (Skills accent)
    amberHi: Color(0xFFFFCA28),
    amber: Color(0xFFF5B800),
    amberLo: Color(0xFFC49000),

    // Emerald (Plugins accent)
    emeraldHi: Color(0xFF34D399),
    emerald: Color(0xFF00C97A),
    emeraldLo: Color(0xFF009E5E),

    // Violet (MCP accent)
    violetHi: Color(0xFFB28DF5),
    violet: Color(0xFF9D68F0),
    violetLo: Color(0xFF7C42D4),
  );

  /// Light theme variant (v2.2 "Design-Refresh heller"). Same glassmorphism
  /// structure and the same Cyan/Fuchsia accent hues as [dark], but on warm
  /// off-white/grey surfaces. Accent tones are darkened/saturated slightly
  /// versus their dark-mode counterparts so they still meet WCAG AA (4.5:1)
  /// contrast against light backgrounds.
  static const AppColors light = AppColors(
    // Background layers — muted warm stone/parchment, deliberately dimmed
    // (v3 refresh: the earlier near-white surfaces read as glaring; these sit
    // closer to paper under warm light than to a lit screen)
    bgBase: Color(0xFFDBD6CD),
    bgSurf: Color(0xFFD2CDC3),
    bgElev: Color(0xFFC9C3B8),
    bgCard: Color(0xFFE6E2D9),

    // Cyan (PRIMARY) — darkened for contrast on the dimmed surfaces
    // (tuned for WCAG AA >= 4.5:1 against bgBase)
    cyanHi: Color(0xFF007A85),
    cyan: Color(0xFF00565E),
    cyanLo: Color(0xFF004A51),
    cyanOrb: Color(0xFF6FBFC9),

    // Fuchsia (SECONDARY) — darkened for contrast on light surfaces
    fuchHi: Color(0xFFA3148E),
    fuch: Color(0xFF821278),
    fuchLo: Color(0xFF680C61),
    fuchOrb: Color(0xFFC98BC6),

    // Text — warm ink on parchment, not cold grey on white
    // (textDim tuned for WCAG AA >= 4.5:1 against bgCard/bgBase)
    textPri: Color(0xFF2A251E),
    textSec: Color(0xFF504A40),
    textDim: Color(0xFF5C564C),
    textDis: Color(0xFF948D80),

    // Amber (Skills accent) — deepened for the dimmed surfaces
    amberHi: Color(0xFF8F6100),
    amber: Color(0xFF775200),
    amberLo: Color(0xFF5E4100),

    // Emerald (Plugins accent)
    emeraldHi: Color(0xFF0B8258),
    emerald: Color(0xFF006F4B),
    emeraldLo: Color(0xFF00583C),

    // Violet (MCP accent)
    violetHi: Color(0xFF6A3FC7),
    violet: Color(0xFF5A2FAF),
    violetLo: Color(0xFF462387),
  );

  @override
  AppColors copyWith({
    Color? bgBase,
    Color? bgSurf,
    Color? bgElev,
    Color? bgCard,
    Color? cyanHi,
    Color? cyan,
    Color? cyanLo,
    Color? cyanOrb,
    Color? fuchHi,
    Color? fuch,
    Color? fuchLo,
    Color? fuchOrb,
    Color? textPri,
    Color? textSec,
    Color? textDim,
    Color? textDis,
    Color? amberHi,
    Color? amber,
    Color? amberLo,
    Color? emeraldHi,
    Color? emerald,
    Color? emeraldLo,
    Color? violetHi,
    Color? violet,
    Color? violetLo,
  }) {
    return AppColors(
      bgBase: bgBase ?? this.bgBase,
      bgSurf: bgSurf ?? this.bgSurf,
      bgElev: bgElev ?? this.bgElev,
      bgCard: bgCard ?? this.bgCard,
      cyanHi: cyanHi ?? this.cyanHi,
      cyan: cyan ?? this.cyan,
      cyanLo: cyanLo ?? this.cyanLo,
      cyanOrb: cyanOrb ?? this.cyanOrb,
      fuchHi: fuchHi ?? this.fuchHi,
      fuch: fuch ?? this.fuch,
      fuchLo: fuchLo ?? this.fuchLo,
      fuchOrb: fuchOrb ?? this.fuchOrb,
      textPri: textPri ?? this.textPri,
      textSec: textSec ?? this.textSec,
      textDim: textDim ?? this.textDim,
      textDis: textDis ?? this.textDis,
      amberHi: amberHi ?? this.amberHi,
      amber: amber ?? this.amber,
      amberLo: amberLo ?? this.amberLo,
      emeraldHi: emeraldHi ?? this.emeraldHi,
      emerald: emerald ?? this.emerald,
      emeraldLo: emeraldLo ?? this.emeraldLo,
      violetHi: violetHi ?? this.violetHi,
      violet: violet ?? this.violet,
      violetLo: violetLo ?? this.violetLo,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSurf: Color.lerp(bgSurf, other.bgSurf, t)!,
      bgElev: Color.lerp(bgElev, other.bgElev, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      cyanHi: Color.lerp(cyanHi, other.cyanHi, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      cyanLo: Color.lerp(cyanLo, other.cyanLo, t)!,
      cyanOrb: Color.lerp(cyanOrb, other.cyanOrb, t)!,
      fuchHi: Color.lerp(fuchHi, other.fuchHi, t)!,
      fuch: Color.lerp(fuch, other.fuch, t)!,
      fuchLo: Color.lerp(fuchLo, other.fuchLo, t)!,
      fuchOrb: Color.lerp(fuchOrb, other.fuchOrb, t)!,
      textPri: Color.lerp(textPri, other.textPri, t)!,
      textSec: Color.lerp(textSec, other.textSec, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textDis: Color.lerp(textDis, other.textDis, t)!,
      amberHi: Color.lerp(amberHi, other.amberHi, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberLo: Color.lerp(amberLo, other.amberLo, t)!,
      emeraldHi: Color.lerp(emeraldHi, other.emeraldHi, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      emeraldLo: Color.lerp(emeraldLo, other.emeraldLo, t)!,
      violetHi: Color.lerp(violetHi, other.violetHi, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      violetLo: Color.lerp(violetLo, other.violetLo, t)!,
    );
  }
}

const _noBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
  borderSide: BorderSide.none,
);

/// Helper to build the standard glassmorphism input decoration.
extension AppColorsInputDecoration on AppColors {
  InputDecoration glassInputDecoration({
    String? hintText,
    String? labelText,
    Color? accentColor,
    bool isDense = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: textDim, fontSize: 14),
      labelText: labelText,
      labelStyle: labelText != null
          ? TextStyle(color: textDim, fontSize: 12)
          : null,
      filled: true,
      fillColor: bgElev.withValues(alpha: 0.4),
      border: _noBorder,
      enabledBorder: _noBorder,
      focusedBorder: accentColor != null
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: accentColor.withValues(alpha: 0.5),
                width: 1,
              ),
            )
          : _noBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: isDense,
    );
  }
}
