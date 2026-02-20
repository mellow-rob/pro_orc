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

  /// Canonical dark theme instance with all 16 pre-computed sRGB tokens.
  static const AppColors dark = AppColors(
    // Background layers
    bgBase: Color(0xFF0A0A0F),
    bgSurf: Color(0xFF0A1017),
    bgElev: Color(0xFF11161E),
    bgCard: Color(0xFF161B22),

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
    );
  }
}
